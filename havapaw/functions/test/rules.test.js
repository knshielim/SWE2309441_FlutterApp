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

test("daily summary: local day in Malaysia time, steps and resting heart rate", () => {
  // 2026-10-20 17:30 UTC is 01:30 on 21 Oct in Kuala Lumpur
  assert.strictEqual(r.localDayKey(Date.parse("2026-10-20T17:30:00Z")), "2026-10-21");
  assert.strictEqual(r.localDayKey(Date.parse("2026-10-20T15:59:00Z")), "2026-10-20");
  assert.deepStrictEqual(r.dailySummaryIncrements({ heartRate: 80, steps: 20 }),
    { stepsSum: 20, stepsN: 1, restHrSum: 80, restHrN: 1 });
  assert.deepStrictEqual(r.dailySummaryIncrements({ heartRate: 120, steps: 400 }), { stepsSum: 400, stepsN: 1, activeN: 1 });
  // missing steps count as resting for the heart-rate baseline (same as the app)
  assert.deepStrictEqual(r.dailySummaryIncrements({ heartRate: 75 }), { restHrSum: 75, restHrN: 1 });
  assert.strictEqual(r.dailySummaryIncrements({ temperature: 38.5 }), null);
});

test("collar off the pet: only counted, never used for activity or baseline", () => {
  assert.strictEqual(r.isOffBody({ temperature: 27.5 }), true);
  assert.strictEqual(r.isOffBody({ temperature: 38.4 }), false);
  assert.strictEqual(r.isOffBody({ heartRate: 80 }), false);
  assert.deepStrictEqual(r.dailySummaryIncrements({ temperature: 28, heartRate: 90, steps: 0 }), { offBodyN: 1 });
});

test("activity goal by species, size and age", () => {
  const now = new Date("2026-11-11T00:00:00Z");
  assert.strictEqual(r.activityGoalMinutes({ type: "cat", birthday: "2020-01-01" }, now), 20);
  assert.strictEqual(r.activityGoalMinutes({ type: "dog", weight: 8, birthday: "2022-01-01" }, now), 40);
  assert.strictEqual(r.activityGoalMinutes({ type: "dog", weight: 25, birthday: "2022-01-01" }, now), 60);
  assert.strictEqual(r.activityGoalMinutes({ type: "dog", weight: 60, birthday: "2022-01-01" }, now), 45);
  assert.strictEqual(r.activityGoalMinutes({ type: "dog", weight: 25, birthday: "2026-06-01" }, now), 30);
  assert.strictEqual(r.activityGoalMinutes({ type: "dog", weight: 25, birthday: "2015-01-01" }, now), 30);
  assert.strictEqual(r.activeMinutes({ activeN: 121 }), 61);
});

test("daily digest message", () => {
  const pet = { name: "Bobby", type: "dog", weight: 25, birthday: "2022-01-01" };
  const now = new Date("2026-11-11T12:00:00Z");
  assert.strictEqual(r.digestMessage(pet, { stepsN: 0 }, [], 0, now), null);
  const calm = r.digestMessage(pet, { stepsN: 400, activeN: 130, restHrSum: 7200, restHrN: 100 },
    [{ restHrSum: 7000, restHrN: 100 }], 0, now);
  assert.strictEqual(calm.title, "Bobby's day");
  assert.match(calm.body, /65 of 60 active minutes \(goal reached\)/);
  assert.match(calm.body, /resting heart rate 72 bpm, normal for Bobby/);
  assert.match(calm.body, /no alerts/);
  const busy = r.digestMessage(pet, { stepsN: 400, activeN: 20, restHrSum: 9000, restHrN: 100 },
    [{ restHrSum: 7000, restHrN: 100 }], 2, now);
  assert.match(busy.body, /10 of 60 active minutes, resting heart rate 90 bpm, higher than usual, 2 alerts\.$/);
});

test("Virtual Vet context: weekly summary and journal, clipped", () => {
  assert.strictEqual(r.formatOwnerContext(null), "");
  const text = r.formatOwnerContext({
    weekly: { restingHr: 72.4, restingHrChange: 3.2, activityChangePct: -18.6, alerts: 1 },
    journal: [
      { date: "2026-11-10", kind: "note", tag: "vomited", text: "after\nlunch " + "x".repeat(400) },
      ...Array.from({ length: 15 }, () => ({ date: "2026-11-09", kind: "checkin", tag: "playing" })),
    ],
  });
  assert.match(text, /resting heart rate 72 bpm, \+3 bpm vs last week, activity -19% vs last week, 1 alert/);
  assert.match(text, /2026-11-10 note: vomited - "after lunch x+"/);
  assert.ok(!text.includes("x".repeat(250)));
  assert.strictEqual((text.match(/^- /gm) || []).length, 10);
});
