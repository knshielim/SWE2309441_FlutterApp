import 'package:cloud_functions/cloud_functions.dart';
import '../models/collar_data.dart';
import '../models/daily_summary.dart';
import '../models/pet.dart';
import 'health_intelligence_service.dart';
import 'ml_health_classifier_service.dart';

class VirtualVetAdvice {
  final String advice;
  final String model;
  final DateTime generatedAt;

  VirtualVetAdvice({
    required this.advice,
    required this.model,
    required this.generatedAt,
  });
}

class VirtualVetService {
  static final _functions = FirebaseFunctions.instance;

  static Future<VirtualVetAdvice> getAdvice({
    required Pet pet,
    required CollarData reading,
    required List<CollarData> historicalData,
    List<DailySummary>? summaries,
    String? question,
  }) async {
    final classification = await MLHealthClassifierService.classify(
      reading,
      pet,
      historicalData,
      summaries: summaries,
    );

    final activityRatio = HealthIntelligenceService.activityRatioFromSummaries(
        summaries ?? DailySummary.fromReadings([...historicalData, reading]));

    final callable = _functions.httpsCallable(
      'generateVirtualVetAdvice',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );

    final result = await callable.call(<String, dynamic>{
      'petName': pet.name,
      'species': pet.type,
      'breed': pet.breed,
      'age': HealthIntelligenceService.calculatePetAge(pet.birthday),
      'weight': pet.weight,
      'reading': {
        'heartRate': reading.heartRate,
        'temperature': reading.temperature,
        'spo2': reading.bloodOxygen,
        'steps': reading.steps,
        'activityRatio': activityRatio != null ? double.parse(activityRatio.toStringAsFixed(2)) : null,
      },
      'classification': {
        'state': classification?.state.name ?? 'unknown',
        'confidence': classification != null
            ? double.parse(classification.confidence.toStringAsFixed(3))
            : null,
      },
      if (question != null && question.trim().isNotEmpty) 'question': question.trim(),
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    return VirtualVetAdvice(
      advice: data['advice'] as String,
      model: data['model'] as String? ?? 'gpt-4o',
      generatedAt: DateTime.tryParse(data['generatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
