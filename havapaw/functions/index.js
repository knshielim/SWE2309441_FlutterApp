/**
 * HavaPaw Cloud Functions - GPT-4 Virtual Vet
 *
 * Implements Phase 5 of the FYP proposal: "GPT-4 is integrated as a Virtual
 * Vet through a Firebase Cloud Function. The system sends the pet's profile,
 * together with a summary of sensor readings to generate plain-language
 * health advice."
 *
 * The OpenAI API key lives ONLY here (as a Firebase secret), never in the
 * Flutter app bundle. The client calls this as an HTTPS Callable Function
 * via the `cloud_functions` Flutter package.
 *
 * SETUP (run once from the functions/ directory):
 *   npm install
 *   firebase functions:secrets:set OPENAI_API_KEY
 *   firebase deploy --only functions
 */

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
