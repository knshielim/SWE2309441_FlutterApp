import 'package:flutter_test/flutter_test.dart';
import 'package:havapaw/models/pet.dart';
import 'package:havapaw/models/collar_data.dart';
import 'package:havapaw/services/health_intelligence_service.dart';

// Test fixture helper: builds a Pet with sensible defaults, overriding only
// what a given test cares about.
Pet _pet({
  String type = 'dog',
  double weight = 20.0,
  int ageYears = 4,
}) {
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

CollarData _reading({
  int? heartRate,
  double? temperature,
  int? steps,
  double? ax,
  double? ay,
  double? az,
  double? spo2,
  DateTime? timestamp,
}) {
  return CollarData(
    deviceId: 'device1',
    deviceName: 'Collar',
    heartRate: heartRate,
    temperature: temperature,
    steps: steps,
    accelerometerX: ax,
    accelerometerY: ay,
    accelerometerZ: az,
    bloodOxygen: spo2,
    timestamp: timestamp ?? DateTime.now(),
  );
}

void main() {
  group('dogSizeClass', () {
    test('boundaries map to the same buckets used by the training pipeline', () {
      expect(HealthIntelligenceService.dogSizeClass(1.5), 'toy');
      expect(HealthIntelligenceService.dogSizeClass(4.9), 'toy');
      expect(HealthIntelligenceService.dogSizeClass(5.0), 'small');
      expect(HealthIntelligenceService.dogSizeClass(11.9), 'small');
      expect(HealthIntelligenceService.dogSizeClass(12.0), 'medium');
      expect(HealthIntelligenceService.dogSizeClass(29.9), 'medium');
      expect(HealthIntelligenceService.dogSizeClass(30.0), 'large');
      expect(HealthIntelligenceService.dogSizeClass(54.9), 'large');
      expect(HealthIntelligenceService.dogSizeClass(55.0), 'giant');
      expect(HealthIntelligenceService.dogSizeClass(90.0), 'giant');
    });
  });

  group('getPopulationRestingHeartRateBaseline', () {
    test('cats get a higher baseline than dogs of comparable age', () {
      final catBaseline = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(
        _pet(type: 'cat', weight: 4.5, ageYears: 4),
      );
      final dogBaseline = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(
        _pet(type: 'dog', weight: 20.0, ageYears: 4),
      );
      expect(catBaseline, greaterThan(dogBaseline));
    });

    test('smaller dogs get a higher baseline than larger dogs', () {
      final toy = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(
        _pet(type: 'dog', weight: 3.0, ageYears: 4),
      );
      final giant = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(
        _pet(type: 'dog', weight: 70.0, ageYears: 4),
      );
      expect(toy, greaterThan(giant));
    });

    test('puppies/kittens run hotter than middle-aged adults', () {
      final young = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(
        _pet(type: 'dog', weight: 20.0, ageYears: 0),
      );
      final adult = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(
        _pet(type: 'dog', weight: 20.0, ageYears: 4),
      );
      expect(young, greaterThan(adult));
    });

    test('senior pets get a lower baseline than middle-aged adults', () {
      final senior = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(
        _pet(type: 'dog', weight: 20.0, ageYears: 10),
      );
      final adult = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(
        _pet(type: 'dog', weight: 20.0, ageYears: 4),
      );
      expect(senior, lessThan(adult));
    });

    test('result always stays within the documented clamp range', () {
      for (final w in [1.0, 3.0, 8.0, 20.0, 40.0, 90.0]) {
        for (final age in [0, 1, 4, 8, 15]) {
          final b = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(
            _pet(type: 'dog', weight: w, ageYears: age),
          );
          expect(b, inInclusiveRange(45.0, 210.0));
        }
      }
    });
  });

  group('calculateActivityIndex', () {
    test('returns squared magnitude of the accelerometer vector', () {
      expect(HealthIntelligenceService.calculateActivityIndex(1.0, 0.0, 0.0), 1.0);
      expect(HealthIntelligenceService.calculateActivityIndex(2.0, 0.0, 0.0), 4.0);
      expect(HealthIntelligenceService.calculateActivityIndex(1.0, 1.0, 1.0), 3.0);
    });

    test('returns 0.0 when any axis is missing', () {
      expect(HealthIntelligenceService.calculateActivityIndex(null, 1.0, 1.0), 0.0);
      expect(HealthIntelligenceService.calculateActivityIndex(1.0, null, 1.0), 0.0);
      expect(HealthIntelligenceService.calculateActivityIndex(1.0, 1.0, null), 0.0);
      expect(HealthIntelligenceService.calculateActivityIndex(null, null, null), 0.0);
    });
  });

  group('calculatePetAge', () {
    test('computes whole years from an ISO birthday string', () {
      final fourYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 4 + 20));
      final birthday = fourYearsAgo.toIso8601String().split('T').first;
      expect(HealthIntelligenceService.calculatePetAge(birthday), 4);
    });

    test('returns 0 for an unparsable birthday instead of throwing', () {
      expect(HealthIntelligenceService.calculatePetAge('not-a-date'), 0);
      expect(HealthIntelligenceService.calculatePetAge(''), 0);
    });
  });

  group('getIndividualizedHeartRateThreshold', () {
    test('young pets get a higher ceiling than the breed default', () {
      final base = HealthIntelligenceService.getIndividualizedHeartRateThreshold(
        _pet(type: 'dog', weight: 10, ageYears: 4),
      );
      final young = HealthIntelligenceService.getIndividualizedHeartRateThreshold(
        _pet(type: 'dog', weight: 10, ageYears: 1),
      );
      expect(young, greaterThan(base));
    });

    test('senior pets get a lower ceiling than the breed default', () {
      final base = HealthIntelligenceService.getIndividualizedHeartRateThreshold(
        _pet(type: 'dog', weight: 10, ageYears: 4),
      );
      final senior = HealthIntelligenceService.getIndividualizedHeartRateThreshold(
        _pet(type: 'dog', weight: 10, ageYears: 9),
      );
      expect(senior, lessThan(base));
    });

    test('heavier pets (>30kg) get a reduced ceiling', () {
      final lean = HealthIntelligenceService.getIndividualizedHeartRateThreshold(
        _pet(type: 'dog', weight: 25, ageYears: 4),
      );
      final heavy = HealthIntelligenceService.getIndividualizedHeartRateThreshold(
        _pet(type: 'dog', weight: 35, ageYears: 4),
      );
      expect(heavy, lessThan(lean));
    });

    test('result always stays within [60, 220]', () {
      for (final type in ['dog', 'cat']) {
        for (final age in [0, 4, 15]) {
          final t = HealthIntelligenceService.getIndividualizedHeartRateThreshold(
            _pet(type: type, weight: 40, ageYears: age),
          );
          expect(t, inInclusiveRange(60.0, 220.0));
        }
      }
    });
  });

  group('getIndividualizedTemperatureThreshold', () {
    test('cats get a higher threshold than dogs at the same age', () {
      final dog = HealthIntelligenceService.getIndividualizedTemperatureThreshold(
        _pet(type: 'dog', ageYears: 4),
      );
      final cat = HealthIntelligenceService.getIndividualizedTemperatureThreshold(
        _pet(type: 'cat', ageYears: 4),
      );
      expect(cat, greaterThan(dog));
    });

    test('senior pets (>10y) get a lower threshold', () {
      final adult = HealthIntelligenceService.getIndividualizedTemperatureThreshold(
        _pet(type: 'dog', ageYears: 5),
      );
      final senior = HealthIntelligenceService.getIndividualizedTemperatureThreshold(
        _pet(type: 'dog', ageYears: 12),
      );
      expect(senior, lessThan(adult));
    });

    test('result always stays within [38.0, 41.0]', () {
      for (final type in ['dog', 'cat']) {
        for (final age in [0, 5, 15]) {
          final t = HealthIntelligenceService.getIndividualizedTemperatureThreshold(
            _pet(type: type, ageYears: age),
          );
          expect(t, inInclusiveRange(38.0, 41.0));
        }
      }
    });
  });

  group('calculateThreeDayAverage', () {
    test('returns 0.0 for empty input', () {
      expect(HealthIntelligenceService.calculateThreeDayAverage([]), 0.0);
    });

    test('averages total daily steps across up to 3 most recent days', () {
      final now = DateTime.now();
      final data = [
        _reading(steps: 1000, timestamp: now),
        _reading(steps: 2000, timestamp: now.subtract(const Duration(days: 1))),
        _reading(steps: 3000, timestamp: now.subtract(const Duration(days: 2))),
      ];
      // (1000 + 2000 + 3000) / 3 days = 2000
      expect(HealthIntelligenceService.calculateThreeDayAverage(data), 2000.0);
    });

    test('sums multiple readings within the same day before averaging', () {
      final now = DateTime.now();
      final data = [
        _reading(steps: 500, timestamp: now),
        _reading(steps: 500, timestamp: now.add(const Duration(hours: 1))),
      ];
      // both readings are "today" -> total 1000 steps / 1 day = 1000
      expect(HealthIntelligenceService.calculateThreeDayAverage(data), 1000.0);
    });
  });
}
