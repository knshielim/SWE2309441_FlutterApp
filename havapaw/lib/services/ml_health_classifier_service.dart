import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/collar_data.dart';
import '../models/pet.dart';
import 'health_intelligence_service.dart';
import 'baseline_calibration_service.dart';

/// The four health/activity states the model predicts (matches proposal
/// Figure 3: "Random Forest classifier ... classifies activity state:
/// resting, active, stressed, anomaly").
enum PetActivityState { resting, active, stressed, anomaly }

class MLClassificationResult {
  final PetActivityState state;
  final double confidence; // 0.0 - 1.0, softmax probability of the winning class
  final Map<PetActivityState, double> allProbabilities;

  MLClassificationResult({
    required this.state,
    required this.confidence,
    required this.allProbabilities,
  });
}

/// Runs on-device inference using a TensorFlow Lite model that was distilled
/// from a Random Forest classifier trained on individualized (per-pet)
/// physiological baselines. See havapaw_ml/ for the training pipeline:
/// the Random Forest itself is trained + evaluated with 5-fold cross
/// validation there; this service loads the compact TFLite network that was
/// distilled from it for on-device deployment, since native Random Forest
/// models don't export to standard TFLite ops.
class MLHealthClassifierService {
  static Interpreter? _interpreter;
  static Map<String, dynamic>? _metadata;
  static bool _loading = false;

  static const _modelAsset = 'assets/ml/pet_health_classifier.tflite';
  static const _metadataAsset = 'assets/ml/model_metadata.json';

  static const List<PetActivityState> _labelOrder = [
    PetActivityState.resting,
    PetActivityState.active,
    PetActivityState.stressed,
    PetActivityState.anomaly,
  ];

  /// Loads the interpreter and normalization metadata. Safe to call
  /// repeatedly; only loads once.
  static Future<void> ensureLoaded() async {
    if (_interpreter != null || _loading) return;
    _loading = true;
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
      final raw = await rootBundle.loadString(_metadataAsset);
      _metadata = jsonDecode(raw) as Map<String, dynamic>;
    } finally {
      _loading = false;
    }
  }

  /// Classifies a single collar reading for [pet], given its 3-day rolling
  /// activity baseline (see HealthIntelligenceService.calculateThreeDayAverage).
  /// Returns null if the model isn't loaded yet or data is insufficient.
  static Future<MLClassificationResult?> classify(
    CollarData reading,
    Pet pet,
    List<CollarData> historicalData,
  ) async {
    await ensureLoaded();
    if (_interpreter == null || _metadata == null) return null;

    final features = buildFeatureVector(reading, pet, historicalData);
    if (features == null) return null;

    final mean = (_metadata!['normalization_mean'] as List).cast<num>();
    final std = (_metadata!['normalization_std'] as List).cast<num>();
    final normalized = normalizeFeatures(features, mean, std);

    final input = [normalized];
    final output = List.filled(1 * _labelOrder.length, 0.0).reshape([1, _labelOrder.length]);

    _interpreter!.run(input, output);

    final probs = (output[0] as List).cast<double>();
    var bestIndex = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[bestIndex]) bestIndex = i;
    }

    final probMap = <PetActivityState, double>{};
    for (var i = 0; i < _labelOrder.length; i++) {
      probMap[_labelOrder[i]] = probs[i];
    }

    return MLClassificationResult(
      state: _labelOrder[bestIndex],
      confidence: probs[bestIndex],
      allProbabilities: probMap,
    );
  }

  /// Builds the exact 11-feature vector the model was trained on:
  /// [heart_rate, temperature, spo2, activity_index, steps,
  ///  activity_ratio_3day, hr_deviation_pct, temp_deviation_c,
  ///  age, weight, species_encoded]
  ///
  /// Public and side-effect free on purpose: this is the layer unit tests
  /// exercise directly (see test/services/ml_health_classifier_service_test.dart).
  /// The TFLite interpreter call in classify() needs native platform
  /// channels that don't exist under plain `flutter test`, so that half of
  /// the pipeline needs an integration test on a real device/emulator
  /// instead -- this split keeps the parts that CAN be unit tested (all the
  /// feature-engineering math) actually covered.
  static List<double>? buildFeatureVector(
    CollarData reading,
    Pet pet,
    List<CollarData> historicalData,
  ) {
    final heartRate = reading.heartRate?.toDouble();
    final temperature = reading.temperature;
    final steps = reading.steps ?? 0;
    if (heartRate == null || temperature == null) return null;

    final spo2 = reading.bloodOxygen ?? 97.5; // sensible default if unavailable
    final activityIndex = HealthIntelligenceService.calculateActivityIndex(
      reading.accelerometerX,
      reading.accelerometerY,
      reading.accelerometerZ,
    );
    // Fall back to a resting-equivalent magnitude (~1g^2) when accelerometer
    // data is missing, matching the training distribution's resting baseline.
    final safeActivityIndex = activityIndex > 0 ? activityIndex : 1.0;

    final threeDayAvg = HealthIntelligenceService.calculateThreeDayAverage(historicalData);
    final activityRatio = threeDayAvg > 0 ? steps / threeDayAvg : 1.0;

    // Calibrated resting HR baseline (population prior blended with the
    // pet's own history over the proposal's 30-day window -- see
    // BaselineCalibrationService). The model was trained on deviation from
    // the RESTING baseline, not the alert ceiling, so this must match
    // resting_hr_baseline() in havapaw_ml/data/generate_dataset.py, not
    // getIndividualizedHeartRateThreshold (which is the alert ceiling).
    final calibrated = BaselineCalibrationService.calibrate(pet, historicalData);
    final tempThreshold = HealthIntelligenceService.getIndividualizedTemperatureThreshold(pet);
    final hrDeviationPct = ((heartRate - calibrated.hrBaseline) / calibrated.hrBaseline) * 100;
    final tempDeviation = temperature - tempThreshold;

    final age = HealthIntelligenceService.calculatePetAge(pet.birthday).toDouble();
    final weight = pet.weight;
    final speciesEncoded = pet.type.toLowerCase() == 'dog' ? 1.0 : 0.0; // matches LabelEncoder alphabetical order (cat=0, dog=1)

    return [
      heartRate,
      temperature,
      spo2,
      safeActivityIndex,
      steps.toDouble(),
      min(activityRatio, 5.0), // clip runaway ratios, matches training clip behavior
      hrDeviationPct,
      tempDeviation,
      age,
      weight,
      speciesEncoded,
    ];
  }

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// Z-score normalization using the training set's per-feature mean/std
  /// (see havapaw_ml/models/feature_stats.json, baked into
  /// assets/ml/model_metadata.json). Pure function -- unit tested directly.
  static List<double> normalizeFeatures(List<double> features, List<num> mean, List<num> std) {
    return List<double>.generate(features.length, (i) {
      final s = std[i].toDouble();
      return (features[i] - mean[i].toDouble()) / (s == 0 ? 1.0 : s);
    });
  }
}
