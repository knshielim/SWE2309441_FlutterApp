"use strict";
/**
 * Pure alert rules used by the Cloud Functions.
 *
 * These mirror the thresholds in the Flutter app
 * (lib/services/health_intelligence_service.dart) so that a push notification
 * and the in-app health screen agree. No Firebase imports here so the logic
 * can be unit tested with `node --test`.
 */

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

/**
 * Health alerts for a single reading. Same conditions as the app:
 * high heart rate, stress (high HR with fewer than 100 steps), high temperature.
 */
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

/** The single most severe health alert, or null. Avoids two pushes for one reading. */
function topHealthAlert(reading, pet, now = new Date()) {
  const all = healthAlerts(reading, pet, now);
  if (all.length === 0) return null;
  return all.reduce((a, b) => (b.severity > a.severity ? b : a));
}

/** True when the reading has a position outside every active zone. null if unknown. */
function isOutsideAllZones(reading, zones) {
  if (!isNum(reading.latitude) || !isNum(reading.longitude)) return null;
  if (!zones || zones.length === 0) return null;
  return zones.every(
    (z) => distanceMeters(reading.latitude, reading.longitude, z.latitude, z.longitude) > z.radius
  );
}

/**
 * Validates and cleans a reading sent by the collar. Unknown fields are dropped.
 * Returns { ok: true, value } or { ok: false, error }.
 */
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
  petAgeYears,
  heartRateThreshold,
  temperatureThreshold,
  distanceMeters,
  healthAlerts,
  topHealthAlert,
  isOutsideAllZones,
  sanitizeReading,
};
