"use strict";
// Alert rules

const DOG_MAX_HR = 140;
const CAT_MAX_HR = 220;
const BASE_TEMP_LIMIT = 39.5;
const LOW_BATTERY_PCT = 15;
const BATTERY_RECOVER_PCT = 25;

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

function petAgeYears(birthday, now = new Date()) {
  const d = new Date(birthday);
  if (Number.isNaN(d.getTime())) return 0;
  let age = now.getUTCFullYear() - d.getUTCFullYear();
  const m = now.getUTCMonth() - d.getUTCMonth();
  if (m < 0 || (m === 0 && now.getUTCDate() < d.getUTCDate())) age--;
  return age;
}

function heartRateThreshold(pet, now = new Date()) {
  const type = String(pet.type || "dog").toLowerCase();
  const age = petAgeYears(pet.birthday, now);
  const weight = Number(pet.weight) || 0;
  let max = type === "cat" ? CAT_MAX_HR : DOG_MAX_HR;
  if (age > 8) max -= 10;
  else if (age < 2) max += 10;
  if (weight > 30) max -= 5;
  return clamp(max, 60, 220);
}

function temperatureThreshold(pet, now = new Date()) {
  const type = String(pet.type || "dog").toLowerCase();
  const age = petAgeYears(pet.birthday, now);
  let t = BASE_TEMP_LIMIT;
  if (age > 10) t -= 0.3;
  if (type === "cat") t += 0.5;
  return clamp(t, 38.0, 41.0);
}

function distanceMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const rad = (x) => (x * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLon = rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

const isNum = (v) => typeof v === "number" && Number.isFinite(v);

function healthAlerts(reading, pet, now = new Date()) {
  const out = [];
  const maxHr = heartRateThreshold(pet, now);
  const maxTemp = temperatureThreshold(pet, now);
  const name = pet.name || "Your pet";

  if (isNum(reading.heartRate) && reading.heartRate > maxHr) {
    const severe = reading.heartRate > maxHr + 20;
    out.push({
      type: "highHeartRate",
      severity: severe ? 0.9 : 0.6,
      title: `${name}: high heart rate`,
      body: `Heart rate is ${Math.round(reading.heartRate)} bpm (limit for ${name} is ${Math.round(maxHr)}). Keep an eye on ${name}.`,
    });
    if (isNum(reading.steps) && reading.steps < 100) {
      out.push({
        type: "stressWarning",
        severity: 0.7,
        title: `${name} may be stressed`,
        body: `High heart rate (${Math.round(reading.heartRate)} bpm) while ${name} is barely moving. Check on ${name}.`,
      });
    }
  }
  if (isNum(reading.temperature) && reading.temperature > maxTemp) {
    const severe = reading.temperature > maxTemp + 1.0;
    out.push({
      type: "highTemperature",
      severity: severe ? 0.9 : 0.6,
      title: `${name}: high temperature`,
      body: `Temperature reads ${reading.temperature.toFixed(1)} \u00b0C (limit ${maxTemp.toFixed(1)} \u00b0C). Consider contacting a vet if it stays high.`,
    });
  }
  return out;
}

function topHealthAlert(reading, pet, now = new Date()) {
  const all = healthAlerts(reading, pet, now);
  if (all.length === 0) return null;
  return all.reduce((a, b) => (b.severity > a.severity ? b : a));
}

function isOutsideAllZones(reading, zones) {
  if (!isNum(reading.latitude) || !isNum(reading.longitude)) return null;
  if (!zones || zones.length === 0) return null;
  return zones.every(
    (z) => distanceMeters(reading.latitude, reading.longitude, z.latitude, z.longitude) > z.radius
  );
}

const REST_STEPS = 100;
const BASELINE_DAYS = 3;
const MIN_BASELINE_SAMPLES = 60; // about 30 minutes of uploads in that state
const DEVIATION_THRESHOLD = 0.35;

function dayKey(ms) {
  return new Date(ms).toISOString().slice(0, 10);
}

function activityState(reading) {
  if (!isNum(reading.steps)) return null;
  return reading.steps < REST_STEPS ? "rest" : "active";
}

function addToDailyStats(daily, reading, today) {
  const out = { ...(daily || {}) };
  const st = activityState(reading);
  if (st && isNum(reading.heartRate)) {
    const day = { ...(out[today] || {}) };
    day[`${st}Sum`] = (day[`${st}Sum`] || 0) + reading.heartRate;
    day[`${st}N`] = (day[`${st}N`] || 0) + 1;
    out[today] = day;
  }
  const keep = Object.keys(out).sort().slice(-(BASELINE_DAYS + 1));
  return Object.fromEntries(keep.map((k) => [k, out[k]]));
}

function baselineHeartRate(daily, today, state) {
  const days = Object.keys(daily || {})
    .filter((k) => k < today)
    .sort()
    .slice(-BASELINE_DAYS);
  let sum = 0;
  let n = 0;
  for (const k of days) {
    sum += daily[k][`${state}Sum`] || 0;
    n += daily[k][`${state}N`] || 0;
  }
  if (n < MIN_BASELINE_SAMPLES) return null;
  return { mean: sum / n, samples: n, days: days.length };
}

function deviationCheck(reading, daily, today) {
  const state = activityState(reading);
  if (!state || !isNum(reading.heartRate)) return null;
  const base = baselineHeartRate(daily, today, state);
  if (!base) return null;
  const deviation = (reading.heartRate - base.mean) / base.mean;
  if (Math.abs(deviation) < DEVIATION_THRESHOLD) return null;
  return { state, baselineHr: base.mean, deviation, baselineDays: base.days };
}

const APP_TIME_ZONE = "Asia/Kuala_Lumpur";
const APP_RESTING_STEPS_CUTOFF = 150;

function localDayKey(ms, timeZone = APP_TIME_ZONE) {
  // en-CA formats as YYYY-MM-DD
  return new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" })
    .format(new Date(ms));
}

function dailySummaryIncrements(reading) {
  const inc = {};
  if (isNum(reading.steps)) {
    inc.stepsSum = reading.steps;
    inc.stepsN = 1;
  }
  if (isNum(reading.heartRate) && (isNum(reading.steps) ? reading.steps : 0) <= APP_RESTING_STEPS_CUTOFF) {
    inc.restHrSum = reading.heartRate;
    inc.restHrN = 1;
  }
  return Object.keys(inc).length ? inc : null;
}

function sanitizeReading(body) {
  const num = (key, lo, hi, int = false) => {
    if (body[key] === undefined || body[key] === null) return undefined;
    const v = Number(body[key]);
    if (!Number.isFinite(v) || v < lo || v > hi) throw new Error(`${key}_out_of_range`);
    return int ? Math.round(v) : v;
  };
  try {
    const clean = {
      heartRate: num("heartRate", 20, 300, true),
      temperature: num("temperature", 20, 45),
      bloodOxygen: num("bloodOxygen", 50, 100),
      steps: num("steps", 0, 100000, true),
      batteryLevel: num("batteryLevel", 0, 100, true),
      latitude: num("latitude", -90, 90),
      longitude: num("longitude", -180, 180),
      accelerometerX: num("accelerometerX", -20, 20),
      accelerometerY: num("accelerometerY", -20, 20),
      accelerometerZ: num("accelerometerZ", -20, 20),
    };
    const value = {};
    for (const [k, v] of Object.entries(clean)) if (v !== undefined) value[k] = v;
    if (Object.keys(value).length === 0) return { ok: false, error: "empty_reading" };
    return { ok: true, value };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

module.exports = {
  LOW_BATTERY_PCT,
  BATTERY_RECOVER_PCT,
  DEVIATION_THRESHOLD,
  petAgeYears,
  heartRateThreshold,
  temperatureThreshold,
  distanceMeters,
  healthAlerts,
  topHealthAlert,
  isOutsideAllZones,
  sanitizeReading,
  dayKey,
  addToDailyStats,
  baselineHeartRate,
  deviationCheck,
  localDayKey,
  dailySummaryIncrements,
};
