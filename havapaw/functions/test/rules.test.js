"use strict";
const test = require("node:test");
const assert = require("node:assert");
const r = require("../lib/rules");

const NOW = new Date("2026-10-20T00:00:00Z");
const dog = (o = {}) => ({ name: "Hava", type: "dog", birthday: "2022-01-01", weight: 20, ...o });

test("heart rate threshold: adult dog, young, senior, heavy, cat, clamp", () => {
  assert.strictEqual(r.heartRateThreshold(dog(), NOW), 140);
  assert.strictEqual(r.heartRateThreshold(dog({ birthday: "2025-06-01" }), NOW), 150);
  assert.strictEqual(r.heartRateThreshold(dog({ birthday: "2015-01-01" }), NOW), 130);
  assert.strictEqual(r.heartRateThreshold(dog({ weight: 35 }), NOW), 135);
  assert.strictEqual(r.heartRateThreshold({ type: "cat", birthday: "2022-01-01", weight: 4 }, NOW), 220);
});

test("temperature threshold: cat +0.5, senior -0.3, clamped to 38..41", () => {
  assert.strictEqual(r.temperatureThreshold(dog(), NOW), 39.5);
  assert.ok(Math.abs(r.temperatureThreshold({ type: "cat", birthday: "2022-01-01" }, NOW) - 40.0) < 1e-9);
  assert.ok(Math.abs(r.temperatureThreshold(dog({ birthday: "2010-01-01" }), NOW) - 39.2) < 1e-9);
});

test("healthAlerts: normal reading raises nothing", () => {
  assert.deepStrictEqual(r.healthAlerts({ heartRate: 90, temperature: 38.5, steps: 300 }, dog(), NOW), []);
});

test("healthAlerts: high HR with low steps gives HR and stress; top is the more severe", () => {
  const all = r.healthAlerts({ heartRate: 150, temperature: 38.5, steps: 10 }, dog(), NOW);
  assert.deepStrictEqual(all.map((a) => a.type).sort(), ["highHeartRate", "stressWarning"]);
  assert.strictEqual(r.topHealthAlert({ heartRate: 150, steps: 10 }, dog(), NOW).type, "stressWarning");
  assert.strictEqual(r.topHealthAlert({ heartRate: 170, steps: 10 }, dog(), NOW).type, "highHeartRate");
});

test("healthAlerts: temperature severity steps up above limit + 1", () => {
  assert.strictEqual(r.topHealthAlert({ temperature: 40.0 }, dog(), NOW).severity, 0.6);
  assert.strictEqual(r.topHealthAlert({ temperature: 40.8 }, dog(), NOW).severity, 0.9);
});

test("healthAlerts ignores missing values", () => {
  assert.deepStrictEqual(r.healthAlerts({ heartRate: null, temperature: undefined }, dog(), NOW), []);
});

test("distance and geofence", () => {
  const d = r.distanceMeters(3.0, 101.0, 3.001, 101.0);
  assert.ok(d > 105 && d < 117, `got ${d}`);
  const zones = [{ latitude: 3.0, longitude: 101.0, radius: 50 }];
  assert.strictEqual(r.isOutsideAllZones({ latitude: 3.0001, longitude: 101.0 }, zones), false);
  assert.strictEqual(r.isOutsideAllZones({ latitude: 3.001, longitude: 101.0 }, zones), true);
  assert.strictEqual(r.isOutsideAllZones({ latitude: 3.001, longitude: 101.0 }, []), null);
  assert.strictEqual(r.isOutsideAllZones({}, zones), null);
  assert.strictEqual(
    r.isOutsideAllZones({ latitude: 3.001, longitude: 101.0 }, [...zones, { latitude: 3.001, longitude: 101.0, radius: 20 }]),
    false
  );
});

test("sanitizeReading keeps known fields, rounds ints, rejects bad ranges", () => {
  const ok = r.sanitizeReading({ heartRate: 88.6, temperature: 38.4, junk: "x", latitude: 3.1, longitude: 101.5 });
  assert.deepStrictEqual(ok, { ok: true, value: { heartRate: 89, temperature: 38.4, latitude: 3.1, longitude: 101.5 } });
  assert.strictEqual(r.sanitizeReading({ heartRate: 900 }).ok, false);
  assert.strictEqual(r.sanitizeReading({ temperature: "abc" }).ok, false);
  assert.strictEqual(r.sanitizeReading({ latitude: 95 }).error, "latitude_out_of_range");
  assert.strictEqual(r.sanitizeReading({}).error, "empty_reading");
});
