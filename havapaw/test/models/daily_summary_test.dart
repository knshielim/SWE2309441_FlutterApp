import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:havapaw/models/collar_data.dart';
import 'package:havapaw/models/daily_summary.dart';
import 'package:havapaw/models/pet.dart';
import 'package:havapaw/services/baseline_calibration_service.dart';
import 'package:havapaw/services/health_intelligence_service.dart';

CollarData _r(String id, DateTime t, {int? hr, int? steps}) => CollarData(
      id: id,
      deviceId: 'HavaPaw-ESP32-1',
      deviceName: 'Collar',
      heartRate: hr,
      steps: steps,
      timestamp: t,
    );

Pet _dog() => Pet(
      name: 'Hava',
      type: 'dog',
      breed: 'Mixed',
      birthday: '2020-01-01',
      weight: 20,
      length: 0,
      height: 0,
      collarId: 'c',
      ownerId: 'o',
    );

void main() {
  group('DailySummary.fromReadings', () {
    test('sums steps per day and resting heart rate (150 steps or fewer, missing steps = 0)', () {
      final day = DateTime(2026, 10, 20, 9);
      final s = DailySummary.fromReadings([
        _r('a', day, hr: 80, steps: 20),
        _r('b', day.add(const Duration(minutes: 1)), hr: 120, steps: 400), // active: no resting HR
        _r('c', day.add(const Duration(minutes: 2)), hr: 70), // no steps: resting
        _r('a', day, hr: 80, steps: 20), // duplicate id counted once
      ]);
      expect(s, hasLength(1));
      expect(s.first.date, '2026-10-20');
      expect(s.first.stepsSum, 420);
      expect(s.first.stepsN, 2);
      expect(s.first.restingHeartRate, 75.0);
    });

    test('reads the server document format', () {
      final s = DailySummary.fromMap(
          {'date': '2026-10-19', 'stepsSum': 900, 'stepsN': 30, 'restHrSum': 2400.0, 'restHrN': 30}, '2026-10-19');
      expect(s.avgStepsPerReading, 30.0);
      expect(s.restingHeartRate, 80.0);
    });
  });

  test('server summaries give the same activity ratio and baseline as raw readings', () {
    final now = DateTime(2026, 10, 20, 18);
    final rng = Random(7);
    final readings = <CollarData>[
      for (var d = 0; d <= 5; d++)
        for (var i = 0; i < 40; i++)
          _r('r$d-$i', now.subtract(Duration(days: d, minutes: i * 7)),
              hr: 60 + rng.nextInt(80), steps: rng.nextBool() ? rng.nextInt(600) : null),
    ];
    final summaries = DailySummary.fromReadings(readings);
    final current = readings.first;

    expect(HealthIntelligenceService.activityRatioFromSummaries(summaries, now: now),
        closeTo(HealthIntelligenceService.calculateActivityRatio(current, readings, now: now)!, 1e-12));
    expect(BaselineCalibrationService.calibrateFromSummaries(_dog(), summaries).hrBaseline,
        closeTo(BaselineCalibrationService.calibrate(_dog(), readings).hrBaseline, 1e-12));
    expect(BaselineCalibrationService.calibrateFromSummaries(_dog(), summaries).daysOfData, 6);
  });

  test('low activity uses server summaries when given', () {
    final now = DateTime(2026, 10, 20, 18);
    String day(int d) => DailySummary.dayKey(now.subtract(Duration(days: d)));
    final summaries = [
      for (var d = 3; d >= 1; d--) DailySummary(date: day(d), stepsSum: 40 * 100, stepsN: 100),
      DailySummary(date: day(0), stepsSum: 20 * 150, stepsN: 150), // today: half of normal
    ];
    final current = _r('x', now, hr: 80, steps: 20);
    expect(
      HealthIntelligenceService.detectLowActivity(current, const [], now: now, summaries: summaries)?.type,
      HealthAlertType.lowActivity,
    );
  });
}
