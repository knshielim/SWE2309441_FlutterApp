import 'package:flutter_test/flutter_test.dart';
import 'package:havapaw/models/pet.dart';
import 'package:havapaw/models/collar_data.dart';
import 'package:havapaw/services/ml_health_classifier_service.dart';

// NOTE ON SCOPE: MLHealthClassifierService.classify() calls the TFLite
// interpreter via dart:ffi, which needs native platform channels that don't
// exist under plain `flutter test` (the Dart VM has no way to load
// pet_health_classifier.tflite the way a real device does). That path needs
// an integration test on a real device/emulator instead (see
// integration_test/ if/when added).
//
// What CAN be fully unit tested -- and is, here -- is everything upstream
// of the interpreter call: buildFeatureVector() and normalizeFeatures() are
// both pure functions with no I/O, so every branch of the feature
// engineering logic is covered without needing a device at all.

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
  group('MLHealthClassifierService.buildFeatureVector', () {
    test('returns null when heart rate is missing', () {
      final pet = _pet();
      final reading = _reading(heartRate: null, temperature: 38.5);
      expect(MLHealthClassifierService.buildFeatureVector(reading, pet, []), isNull);
    });

    test('returns null when temperature is missing', () {
      final pet = _pet();
      final reading = _reading(heartRate: 90, temperature: null);
      expect(MLHealthClassifierService.buildFeatureVector(reading, pet, []), isNull);
    });

    test('produces exactly 11 features in the trained order', () {
      final pet = _pet();
      final reading = _reading(heartRate: 90, temperature: 38.5, steps: 100, ax: 0.1, ay: 0.1, az: 1.0, spo2: 97.0);
      final features = MLHealthClassifierService.buildFeatureVector(reading, pet, []);
      expect(features, isNotNull);
      expect(features!.length, 11);
    });

    test('defaults SpO2 to 97.5 when the sensor value is missing', () {
      final pet = _pet();
      final reading = _reading(heartRate: 90, temperature: 38.5, spo2: null);
      final features = MLHealthClassifierService.buildFeatureVector(reading, pet, []);
      // index 2 = spo2, per the documented feature order
      expect(features![2], 97.5);
    });

    test('falls back to a resting-equivalent activity index when accelerometer data is missing', () {
      final pet = _pet();
      final reading = _reading(heartRate: 90, temperature: 38.5, ax: null, ay: null, az: null);
      final features = MLHealthClassifierService.buildFeatureVector(reading, pet, []);
      // index 3 = activity_index
      expect(features![3], 1.0);
    });

    test('computes a real activity index from accelerometer data when present', () {
      final pet = _pet();
      final reading = _reading(heartRate: 90, temperature: 38.5, ax: 2.0, ay: 0.0, az: 0.0);
      final features = MLHealthClassifierService.buildFeatureVector(reading, pet, []);
      expect(features![3], 4.0); // 2^2 + 0^2 + 0^2
    });

    test('encodes species as documented: cat=0, dog=1', () {
      final catFeatures = MLHealthClassifierService.buildFeatureVector(
        _reading(heartRate: 170, temperature: 38.8),
        _pet(type: 'cat', weight: 4.5),
        [],
      );
      final dogFeatures = MLHealthClassifierService.buildFeatureVector(
        _reading(heartRate: 90, temperature: 38.5),
        _pet(type: 'dog', weight: 20.0),
        [],
      );
      // index 10 = species_encoded
      expect(catFeatures![10], 0.0);
      expect(dogFeatures![10], 1.0);
    });

    test('a heart rate exactly at the calibrated baseline gives ~0% deviation', () {
      final pet = _pet(type: 'dog', weight: 20.0, ageYears: 4); // medium dog, no history -> pure population prior (~90bpm)
      final reading = _reading(heartRate: 90, temperature: 38.5);
      final features = MLHealthClassifierService.buildFeatureVector(reading, pet, []);
      // index 6 = hr_deviation_pct
      expect(features![6], closeTo(0.0, 1.0));
    });

    test('an elevated heart rate produces a clearly positive deviation', () {
      final pet = _pet(type: 'dog', weight: 20.0, ageYears: 4);
      final reading = _reading(heartRate: 180, temperature: 38.5); // roughly double the ~90bpm baseline
      final features = MLHealthClassifierService.buildFeatureVector(reading, pet, []);
      expect(features![6], greaterThan(50.0));
    });

    test('activity ratio is clipped so a runaway spike does not blow out the feature', () {
      final pet = _pet();
      final now = DateTime.now();
      // historical average will be very small (10 steps/day), so a large
      // current step count would otherwise produce a huge ratio
      final history = [_reading(steps: 10, timestamp: now.subtract(const Duration(days: 1)))];
      final reading = _reading(heartRate: 90, temperature: 38.5, steps: 50000, timestamp: now);
      final features = MLHealthClassifierService.buildFeatureVector(reading, pet, history);
      // index 5 = activity_ratio_3day, clipped at 5.0 per the training pipeline
      expect(features![5], 5.0);
    });

    test('activity ratio defaults to 1.0 when there is no historical baseline yet', () {
      final pet = _pet();
      final reading = _reading(heartRate: 90, temperature: 38.5, steps: 300);
      final features = MLHealthClassifierService.buildFeatureVector(reading, pet, []);
      expect(features![5], 1.0);
    });
  });

  group('MLHealthClassifierService.normalizeFeatures', () {
    test('applies z-score normalization per feature', () {
      final features = [10.0, 20.0, 30.0];
      final mean = [10.0, 10.0, 10.0];
      final std = [5.0, 5.0, 5.0];
      final normalized = MLHealthClassifierService.normalizeFeatures(features, mean, std);
      expect(normalized, [0.0, 2.0, 4.0]);
    });

    test('treats a zero std as 1.0 to avoid divide-by-zero', () {
      final features = [10.0];
      final mean = [4.0];
      final std = [0.0];
      final normalized = MLHealthClassifierService.normalizeFeatures(features, mean, std);
      expect(normalized, [6.0]); // (10 - 4) / 1, not a NaN/Infinity from /0
    });
  });
}
