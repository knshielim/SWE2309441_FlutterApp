// Cloud Functions: Virtual Vet, collar upload and alerts
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const OpenAI = require("openai");

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

const SYSTEM_PROMPT = `You are the "Virtual Vet" feature inside HavaPaw, a smart pet collar app.
You receive a pet's profile and a summary of recent sensor readings plus a
machine-learning classification of the pet's current state (resting, active,
stressed, or anomaly). Your job is to translate that into short, warm,
plain-language guidance a non-expert owner can act on.

Rules:
- Never provide a diagnosis. You are not a substitute for a licensed veterinarian.
- If the state is "anomaly" or confidence is high on "stressed", clearly
  recommend contacting a vet, but stay calm and non-alarming.
- Keep the response to 3-5 short sentences plus up to 3 bullet-point next steps.
- Reference the pet by name and be specific about which reading(s) triggered
  the note (e.g. "your heart rate reading was..."), not generic filler.
- Always end with a brief reminder that this is guidance, not a diagnosis.
- If the owner asks a specific free-text question, answer THAT question
  directly first, still grounded in the sensor data and classification
  provided, before adding any extra notes.`;

// Virtual Vet (GPT-4)
exports.generateVirtualVetAdvice = onCall(
  { secrets: [OPENAI_API_KEY], cors: true, maxInstances: 10 },
  async (request) => {
    const data = request.data || {};
    const { petName, species, breed, age, weight, reading, classification, question } = data;

    if (!petName || !reading || !classification) {
      throw new HttpsError(
        "invalid-argument",
        "petName, reading, and classification are required."
      );
    }

    const trimmedQuestion = typeof question === "string" ? question.trim() : "";

    const userPrompt = `Pet profile:
- Name: ${petName}
- Species: ${species ?? "unknown"}
- Breed: ${breed ?? "unknown"}
- Age: ${age ?? "unknown"} years
- Weight: ${weight ?? "unknown"} kg

Latest sensor reading:
- Heart rate: ${reading.heartRate ?? "n/a"} bpm
- Temperature: ${reading.temperature ?? "n/a"} degC
- Blood oxygen (SpO2): ${reading.spo2 ?? "n/a"}%
- Steps (recent window): ${reading.steps ?? "n/a"}
- Activity vs 3-day baseline: ${reading.activityRatio ?? "n/a"}x

ML classification:
- Predicted state: ${classification.state}
- Confidence: ${classification.confidence ?? "n/a"}

${trimmedQuestion
  ? `The owner asked: "${trimmedQuestion}"\n\nAnswer their question first, grounded in the data above.`
  : "Write the Virtual Vet note for the owner now."}`;

    try {
      const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
      const completion = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.4,
        max_tokens: 350,
      });

      const advice = completion.choices?.[0]?.message?.content?.trim();
      if (!advice) {
        throw new HttpsError("internal", "Empty response from model.");
      }

      return {
        advice,
        model: completion.model,
        generatedAt: new Date().toISOString(),
      };
    } catch (err) {
      logger.error("Virtual Vet generation failed", err);
      throw new HttpsError("internal", "Failed to generate Virtual Vet advice.");
    }
  }
);

const crypto = require("crypto");
const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const rules = require("./lib/rules");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const MIN_INGEST_INTERVAL_MS = 4000;
const HEALTH_COOLDOWN_MS = 15 * 60 * 1000;
const GEOFENCE_COOLDOWN_MS = 5 * 60 * 1000;
const CONSECUTIVE_READINGS_REQUIRED = 2; // ignore one-off sensor spikes

function safeEqual(a, b) {
  const ba = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  return ba.length === bb.length && crypto.timingSafeEqual(ba, bb);
}

// Collar upload endpoint
exports.ingestCollarData = onRequest(
  { cors: false, maxInstances: 20, invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }
    const body = req.body && typeof req.body === "object" ? req.body : {};
    const token = req.get("X-Device-Token") || "";
    const deviceId = typeof body.deviceId === "string" ? body.deviceId : "";
    if (!deviceId || deviceId.length > 64 || token.length !== 64) {
      res.status(400).json({ error: "bad_request" });
      return;
    }

    const regRef = db.collection("deviceTokens").doc(deviceId);
    const reg = await regRef.get();
    if (!reg.exists || !safeEqual(reg.get("token") || "", token)) {
      res.status(401).json({ error: "unauthorized" });
      return;
    }
    const uid = reg.get("uid");
    const petId = reg.get("petId");
    if (!uid || !petId) {
      res.status(401).json({ error: "unbound_device" });
      return;
    }

    const now = Date.now();
    if (now - (reg.get("lastIngestMs") || 0) < MIN_INGEST_INTERVAL_MS) {
      res.status(429).json({ error: "too_many_requests" });
      return;
    }

    const parsed = rules.sanitizeReading(body);
    if (!parsed.ok) {
      res.status(400).json({ error: parsed.error });
      return;
    }

    // Trust the device clock only if it is close to the server clock.
    let timestamp = new Date(now).toISOString();
    if (typeof body.timestamp === "string") {
      const t = Date.parse(body.timestamp);
      if (!Number.isNaN(t) && Math.abs(t - now) < 10 * 60 * 1000) timestamp = new Date(t).toISOString();
    }

    await Promise.all([
      db.collection("users").doc(uid).collection("collarData").add({
        ...parsed.value,
        deviceId,
        deviceName: deviceId,
        petId,
        timestamp,
      }),
      regRef.set({ lastIngestMs: now }, { merge: true }),
    ]);
    res.status(200).json({ ok: true });
  }
);

const DEVIATION_SYSTEM_PROMPT = `You write push notifications for HavaPaw, a smart pet collar app.
A reading from the pet's collar differs from that pet's own normal (its personal
baseline over the previous days). Write 2 short sentences, at most 220 characters
in total, in plain language for a non-expert owner: say what changed compared
with the pet's normal, and one concrete thing to do now. Stay calm. Never give a
diagnosis. If the change is large or the temperature is high, suggest contacting
a vet. Plain text only, no emoji, no markdown.`;

// GPT-4 note for a baseline deviation
async function deviationAlert(pet, reading, dev) {
  const name = pet.name || "Your pet";
  const pct = Math.round(Math.abs(dev.deviation) * 100);
  const dir = dev.deviation > 0 ? "higher" : "lower";
  const stateText = dev.state === "rest" ? "resting" : "active";
  const alert = {
    type: "baselineDeviation",
    severity: Math.abs(dev.deviation) >= 0.5 ? 0.85 : 0.65,
    title: `${name}'s heart rate is ${pct}% ${dir} than usual`,
    // Used if GPT-4 is unavailable.
    body: `${name}'s ${stateText} heart rate is ${Math.round(reading.heartRate)} bpm; ` +
      `normal for ${name} is about ${Math.round(dev.baselineHr)} bpm. Check on ${name}.`,
    deviation: dev.deviation,
    baselineHr: dev.baselineHr,
  };
  try {
    const age = rules.petAgeYears(pet.birthday);
    const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value(), timeout: 15000, maxRetries: 1 });
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        { role: "system", content: DEVIATION_SYSTEM_PROMPT },
        {
          role: "user",
          content: `Pet: ${name}, ${pet.type || "unknown species"}, breed ${pet.breed || "unknown"}, ` +
            `${age || "unknown"} years, ${pet.weight || "unknown"} kg.
State: ${stateText} (${reading.steps} steps in the last 5 minutes).
Heart rate now: ${Math.round(reading.heartRate)} bpm. Personal ${stateText} baseline: ` +
            `${Math.round(dev.baselineHr)} bpm over the previous ${dev.baselineDays} day(s) (${pct}% ${dir}).
Temperature: ${reading.temperature ?? "n/a"} degC. SpO2: ${reading.bloodOxygen ?? "n/a"}%.`,
        },
      ],
      temperature: 0.3,
      max_tokens: 120,
    });
    const text = completion.choices?.[0]?.message?.content?.trim();
    if (text) {
      alert.body = text.length > 300 ? `${text.slice(0, 297)}...` : text;
      alert.generatedBy = completion.model;
    }
  } catch (e) {
    logger.warn("GPT-4 deviation note failed; sending the fallback text", e);
  }
  return alert;
}

// Push notification
async function sendPush(uid, petId, alert) {
  const tokensSnap = await db.collection("users").doc(uid).collection("fcmTokens").get();
  const tokens = tokensSnap.docs.map((d) => d.id);
  await db.collection("users").doc(uid).collection("alerts").add({
    petId,
    type: alert.type,
    severity: alert.severity,
    title: alert.title,
    body: alert.body,
    ...(alert.deviation !== undefined && {
      deviation: alert.deviation,
      baselineHr: alert.baselineHr,
      generatedBy: alert.generatedBy || "fallback",
    }),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  if (tokens.length === 0) return;
  const result = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title: alert.title, body: alert.body },
    data: { type: alert.type, petId: String(petId) },
    android: {
      priority: "high",
      notification: { channelId: "havapaw_channel" },
    },
    apns: { payload: { aps: { sound: "default" } } },
  });
  const dead = [];
  result.responses.forEach((r, i) => {
    const code = r.error && r.error.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      dead.push(tokens[i]);
    }
  });
  await Promise.all(
    dead.map((t) => db.collection("users").doc(uid).collection("fcmTokens").doc(t).delete())
  );
}

// Alerts for each new collar reading
exports.onCollarReading = onDocumentCreated(
  { document: "users/{uid}/collarData/{docId}", maxInstances: 20, secrets: [OPENAI_API_KEY] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const reading = snap.data();
    const uid = event.params.uid;
    const petId = reading.petId;
    if (!petId) return;

    const userRef = db.collection("users").doc(uid);
    const stateRef = userRef.collection("alertState").doc(petId);
    const [petDoc, userDoc, zonesSnap, stateDoc] = await Promise.all([
      userRef.collection("pets").doc(petId).get(),
      userRef.get(),
      userRef.collection("geofences").where("petId", "==", petId).where("isActive", "==", true).get(),
      stateRef.get(),
    ]);
    if (!petDoc.exists) return;

    // Daily summary for the app (written whatever the alert settings are).
    const inc = rules.dailySummaryIncrements(reading);
    if (inc) {
      const tsMs = Date.parse(reading.timestamp);
      const day = rules.localDayKey(Number.isNaN(tsMs) ? Date.now() : tsMs);
      const fields = { date: day, updatedAt: admin.firestore.FieldValue.serverTimestamp() };
      for (const [k, v] of Object.entries(inc)) fields[k] = admin.firestore.FieldValue.increment(v);
      try {
        await userRef.collection("pets").doc(petId).collection("dailyStats").doc(day).set(fields, { merge: true });
      } catch (e) {
        logger.error("dailyStats update failed", e);
      }
    }

    const pet = petDoc.data();
    const prefs = (userDoc.exists && userDoc.get("alertPrefs")) || {};
    if (prefs.push === false) return;
    const onWalk = userDoc.exists && userDoc.get("onWalk") === true;
    const zones = zonesSnap.docs.map((d) => d.data());

    const state = stateDoc.exists ? stateDoc.data() : {};
    const counts = { ...(state.counts || {}) };
    const lastSent = { ...(state.lastSent || {}) };
    let lowBattery = state.lowBattery === true;
    let outside = state.outside === true;
    const now = Date.now();
    const toSend = [];

    // health (one alert per reading, only after consecutive abnormal readings)
    const hasVitals = typeof reading.heartRate === "number" || typeof reading.temperature === "number";
    if (hasVitals) {
      const top = rules.topHealthAlert(reading, pet);
      for (const t of ["highHeartRate", "stressWarning", "highTemperature"]) {
        counts[t] = top && top.type === t ? (counts[t] || 0) + 1 : 0;
      }
      if (
        top &&
        prefs.health !== false &&
        counts[top.type] >= CONSECUTIVE_READINGS_REQUIRED &&
        now - (lastSent[top.type] || 0) > HEALTH_COOLDOWN_MS
      ) {
        toSend.push(top);
        lastSent[top.type] = now;
      }
    }

    const today = rules.dayKey(now);
    const daily = state.daily || {};
    const dev = rules.deviationCheck(reading, daily, today);
    counts.deviation = dev ? (counts.deviation || 0) + 1 : 0;
    if (
      dev &&
      prefs.health !== false &&
      toSend.length === 0 &&
      counts.deviation >= CONSECUTIVE_READINGS_REQUIRED &&
      now - (lastSent.deviation || 0) > HEALTH_COOLDOWN_MS
    ) {
      lastSent.deviation = now;
      toSend.push(await deviationAlert(pet, reading, dev));
    }
    const newDaily = rules.addToDailyStats(daily, reading, today);

    // low battery (once per discharge cycle)
    if (typeof reading.batteryLevel === "number") {
      if (reading.batteryLevel < rules.LOW_BATTERY_PCT && !lowBattery) {
        lowBattery = true;
        if (prefs.battery !== false) {
          toSend.push({
            type: "lowBattery",
            severity: 0.5,
            title: `${pet.name || "Collar"}: battery low`,
            body: `Collar battery is at ${reading.batteryLevel}%. Charge it soon so tracking keeps working.`,
          });
        }
      } else if (reading.batteryLevel >= rules.BATTERY_RECOVER_PCT) {
        lowBattery = false;
      }
    }

    // geofence (on exit; suppressed while the owner has Walk mode on)
    const out = rules.isOutsideAllZones(reading, zones);
    if (out === true) {
      counts.outside = (counts.outside || 0) + 1;
      if (
        !outside &&
        !onWalk &&
        counts.outside >= CONSECUTIVE_READINGS_REQUIRED &&
        now - (lastSent.geofence || 0) > GEOFENCE_COOLDOWN_MS
      ) {
        outside = true;
        lastSent.geofence = now;
        if (prefs.geofence !== false) {
          toSend.push({
            type: "geofenceExit",
            severity: 0.8,
            title: `${pet.name || "Your pet"} left the safe zone`,
            body: `${pet.name || "Your pet"} is outside the safe zone. Open the map to see where.`,
          });
        }
      }
    } else if (out === false) {
      counts.outside = 0;
      outside = false;
    }

    // No merge: old days must drop out of the daily map.
    await stateRef.set({ counts, lastSent, lowBattery, outside, daily: newDaily, updatedAt: now });
    for (const alert of toSend) {
      try {
        await sendPush(uid, petId, alert);
      } catch (e) {
        logger.error("sendPush failed", e);
      }
    }
  }
);
