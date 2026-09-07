import 'package:flutter_test/flutter_test.dart';
import 'package:havapaw/models/pet.dart';
import 'package:havapaw/models/collar_data.dart';
import 'package:havapaw/services/health_intelligence_service.dart';
import 'package:havapaw/services/baseline_calibration_service.dart';

Pet _pet({String type = 'dog', double weight = 20.0, int ageYears = 4}) {
  final birthday = DateTime.now().subtract(Duration(days: 365 * ageYears + 10));
  return Pet(
    name: 'TestPet',
    type: type,
    breed: 'Mixed',
    birthday: birthday.toIso8601String().split('T').first,
    weight: weight,
    length: 40.0,
    height: 30.0,
    collarId: 'collar1',
    ownerId: 'owner1',
  );
}

CollarData _restingReading(int heartRate, DateTime timestamp, {int steps = 20}) {
  return CollarData(
    deviceId: 'device1',
    deviceName: 'Collar',
    heartRate: heartRate,
    steps: steps, // below the 150-step resting cutoff
    timestamp: timestamp,
  );
}

CollarData _activeReading(int heartRate, DateTime timestamp) {
  return CollarData(
    deviceId: 'device1',
    deviceName: 'Collar',
    heartRate: heartRate,
    steps: 800, // above the resting cutoff -> excluded from baseline calc
    timestamp: timestamp,
  );
}

void main() {
  group('BaselineCalibrationService.calibrate', () {
    test('falls back to the population prior with zero data', () {
      final pet = _pet();
      final result = BaselineCalibrationService.calibrate(pet, []);
      final expectedPrior = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(pet);

      expect(result.usedFallback, isTrue);
      expect(result.daysOfData, 0);
      expect(result.maturity, 0.0);
      expect(result.hrBaseline, expectedPrior);
    });

    test('falls back to the population prior when historical data has no usable heart rate', () {
      final pet = _pet();
      final now = DateTime.now();
      final noisyData = [
        CollarData(deviceId: 'd', deviceName: 'c', timestamp: now, steps: 10), // no heartRate
      ];
      final result = BaselineCalibrationService.calibrate(pet, noisyData);
      expect(result.usedFallback, isTrue);
    });

    test('excludes active (high-step) readings from the resting baseline', () {
      final pet = _pet();
      final now = DateTime.now();
      // All "active" readings at an unrealistic 220 bpm -- if these leaked
      // into the resting baseline, hrBaseline would shoot up dramatically.
      final data = List.generate(
        5,
        (i) => _activeReading(220, now.subtract(Duration(days: i))),
      );
      final result = BaselineCalibrationService.calibrate(pet, data);
      // No resting-state days found -> falls back to population prior, NOT
      // an inflated baseline built from active readings.
      expect(result.usedFallback, isTrue);
    });

    test('blends toward the individual as resting data accumulates, and never overshoots it', () {
      final pet = _pet(type: 'dog', weight: 20.0, ageYears: 4); // population prior ~90bpm
      final now = DateTime.now();
      const individualTrueRestingHr = 110; // this pet genuinely runs a bit faster than the formula predicts

      final oneDayData = [_restingReading(individualTrueRestingHr, now)];
      final oneDay = BaselineCalibrationService.calibrate(pet, oneDayData);

      final thirtyDayData = List.generate(
        30,
        (i) => _restingReading(individualTrueRestingHr, now.subtract(Duration(days: i))),
      );
      final thirtyDays = BaselineCalibrationService.calibrate(pet, thirtyDayData);

      final populationPrior = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(pet);

      // Both should sit between the prior and the individual's true value...
      expect(oneDay.hrBaseline, greaterThan(populationPrior));
      expect(oneDay.hrBaseline, lessThan(individualTrueRestingHr.toDouble()));
      expect(thirtyDays.hrBaseline, greaterThan(populationPrior));
      expect(thirtyDays.hrBaseline, lessThanOrEqualTo(individualTrueRestingHr.toDouble()));

      // ...and 30 days of consistent data should pull noticeably closer to
      // the individual's true value than a single day does.
      final oneDayGap = (individualTrueRestingHr - oneDay.hrBaseline).abs();
      final thirtyDayGap = (individualTrueRestingHr - thirtyDays.hrBaseline).abs();
      expect(thirtyDayGap, lessThan(oneDayGap));
    });

    test('maturity reaches 1.0 at 30+ distinct days of data, not before', () {
      final pet = _pet();
      final now = DateTime.now();

      final tenDays = List.generate(10, (i) => _restingReading(95, now.subtract(Duration(days: i))));
      final thirtyDays = List.generate(30, (i) => _restingReading(95, now.subtract(Duration(days: i))));
      final sixtyDays = List.generate(60, (i) => _restingReading(95, now.subtract(Duration(days: i))));

      expect(BaselineCalibrationService.calibrate(pet, tenDays).maturity, closeTo(10 / 30, 0.001));
      expect(BaselineCalibrationService.calibrate(pet, thirtyDays).maturity, 1.0);
      expect(BaselineCalibrationService.calibrate(pet, sixtyDays).maturity, 1.0); // clamped, not 2.0
    });

    test('multiple readings on the same day count as one day of data, not several', () {
      final pet = _pet();
      final now = DateTime.now();
      final data = [
        _restingReading(95, now),
        _restingReading(97, now.add(const Duration(hours: 2))),
        _restingReading(93, now.add(const Duration(hours: 4))),
      ];
      final result = BaselineCalibrationService.calibrate(pet, data);
      expect(result.daysOfData, 1);
    });

    test('the alert ceiling shifts by the same offset as the baseline', () {
      final pet = _pet(type: 'dog', weight: 20.0, ageYears: 4);
      final now = DateTime.now();
      final data = List.generate(30, (i) => _restingReading(115, now.subtract(Duration(days: i))));

      final result = BaselineCalibrationService.calibrate(pet, data);
      final populationBaseline = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(pet);
      final populationThreshold = HealthIntelligenceService.getIndividualizedHeartRateThreshold(pet);

      final baselineOffset = result.hrBaseline - populationBaseline;
      final thresholdOffset = result.hrThreshold - populationThreshold;
      // Allow tiny floating point drift only.
      expect((baselineOffset - thresholdOffset).abs(), lessThan(0.01));
    });
  });
}
