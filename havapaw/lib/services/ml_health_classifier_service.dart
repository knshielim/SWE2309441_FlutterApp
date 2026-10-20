// Random Forest (TFLite) health classifier
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/collar_data.dart';
import '../models/daily_summary.dart';
import '../models/pet.dart';
import 'health_intelligence_service.dart';
import 'baseline_calibration_service.dart';

enum PetActivityState { resting, active, stressed, anomaly }

class MLClassificationResult {
  final PetActivityState state;
  final double confidence;
  final Map<PetActivityState, double> allProbabilities;

  MLClassificationResult({
    required this.state,
    required this.confidence,
    required this.allProbabilities,
  });
}

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

  static Future<MLClassificationResult?> classify(
    CollarData reading,
    Pet pet,
    List<CollarData> historicalData, {
    List<DailySummary>? summaries,
  }) async {
    await ensureLoaded();
    if (_interpreter == null || _metadata == null) return null;

    final features = buildFeatureVector(reading, pet, historicalData, summaries: summaries);
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

  static List<double>? buildFeatureVector(
    CollarData reading,
    Pet pet,
    List<CollarData> historicalData, {
    List<DailySummary>? summaries,
  }) {
    final days = summaries ?? DailySummary.fromReadings([...historicalData, reading]);
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
    final safeActivityIndex = activityIndex > 0 ? activityIndex : 1.0;

    final activityRatio = HealthIntelligenceService.activityRatioFromSummaries(days) ?? 1.0;

    final calibrated = BaselineCalibrationService.calibrateFromSummaries(pet, days);
    final tempThreshold = HealthIntelligenceService.getIndividualizedTemperatureThreshold(pet);
    final hrDeviationPct = ((heartRate - calibrated.hrBaseline) / calibrated.hrBaseline) * 100;
    final tempDeviation = temperature - tempThreshold;

    final age = HealthIntelligenceService.calculatePetAge(pet.birthday).toDouble();
    final weight = pet.weight;
    final speciesEncoded = pet.type.toLowerCase() == 'dog' ? 1.0 : 0.0;

    return [
      heartRate,
      temperature,
      spo2,
      safeActivityIndex,
      steps.toDouble(),
      min(activityRatio, 5.0),
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

  static List<double> normalizeFeatures(List<double> features, List<num> mean, List<num> std) {
    return List<double>.generate(features.length, (i) {
      final s = std[i].toDouble();
      return (features[i] - mean[i].toDouble()) / (s == 0 ? 1.0 : s);
    });
  }
}
