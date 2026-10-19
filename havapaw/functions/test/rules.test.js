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

test("daily stats: split by rest/active, keep last 4 days, skip readings without steps", () => {
  let d = {};
  d = r.addToDailyStats(d, { heartRate: 80, steps: 10 }, "2026-10-01");
  d = r.addToDailyStats(d, { heartRate: 120, steps: 400 }, "2026-10-01");
  d = r.addToDailyStats(d, { heartRate: 90 }, "2026-10-01");
  assert.deepStrictEqual(d["2026-10-01"], { restSum: 80, restN: 1, activeSum: 120, activeN: 1 });
  for (const day of ["2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05"]) {
    d = r.addToDailyStats(d, { heartRate: 80, steps: 10 }, day);
  }
  assert.deepStrictEqual(Object.keys(d), ["2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05"]);
});

test("deviation: needs a baseline from earlier days, compares like with like, 35% threshold", () => {
  const day = (restMean, activeMean, n = 40) => ({
    restSum: restMean * n, restN: n, activeSum: activeMean * n, activeN: n,
  });
  const daily = { "2026-10-02": day(80, 120), "2026-10-03": day(80, 120), "2026-10-04": day(80, 120) };
  const today = "2026-10-05";

  // no history yet
  assert.strictEqual(r.deviationCheck({ heartRate: 200, steps: 10 }, {}, today), null);
  // today's own data is not part of the baseline
  assert.strictEqual(r.deviationCheck({ heartRate: 200, steps: 10 }, { [today]: day(80, 120, 500) }, today), null);
  // a walk is compared with the active baseline: 150 vs 120 is +25%, no alert
  assert.strictEqual(r.deviationCheck({ heartRate: 150, steps: 400 }, daily, today), null);
  // resting at 110 vs 80 is +37.5%
  const dev = r.deviationCheck({ heartRate: 110, steps: 10 }, daily, today);
  assert.strictEqual(dev.state, "rest");
  assert.strictEqual(dev.baselineHr, 80);
  assert.ok(Math.abs(dev.deviation - 0.375) < 1e-9);
  // drops count too: 50 vs 80 is -37.5%
  assert.ok(r.deviationCheck({ heartRate: 50, steps: 10 }, daily, today).deviation < 0);
  // only the last 3 earlier days count
  const old = { "2026-09-30": day(200, 200, 1000), ...daily };
  assert.strictEqual(r.deviationCheck({ heartRate: 100, steps: 10 }, old, today), null);
});
