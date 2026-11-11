import 'package:cloud_functions/cloud_functions.dart';
import '../models/collar_data.dart';
import '../models/daily_summary.dart';
import '../models/pet.dart';
import 'health_intelligence_service.dart';
import 'ml_health_classifier_service.dart';
import '../models/journal_entry.dart';
import '../models/weekly_summary.dart';
import 'alert_history_service.dart';
import 'journal_service.dart';

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

    final context = await ownerContext(pet.id ?? '', summaries ?? const []);

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
      if (context != null) 'context': context,
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    return VirtualVetAdvice(
      advice: data['advice'] as String,
      model: data['model'] as String? ?? 'gpt-4o',
      generatedAt: DateTime.tryParse(data['generatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // Weekly summary and the last week's journal, so the advice can mention recent events
  static Future<Map<String, dynamic>?> ownerContext(String petId, List<DailySummary> summaries) async {
    if (petId.isEmpty) return null;
    try {
      final results = await Future.wait([
        JournalService.streamForPet(petId, limit: 30).first,
        AlertHistoryService.streamAlerts(limit: 100).first,
      ]).timeout(const Duration(seconds: 6));
      final entries = results[0] as List<JournalEntry>;
      final alerts = (results[1] as List<AlertRecord>).where((a) => a.petId == petId);
      return buildContext(
        WeeklySummary.build(
          summaries: summaries,
          alertTimes: [for (final a in alerts) if (a.createdAt != null) a.createdAt!],
          entries: entries,
        ),
        entries,
      );
    } catch (_) {
      return null; // advice still works without it
    }
  }

  static Map<String, dynamic> buildContext(WeeklySummary weekly, List<JournalEntry> entries, {DateTime? now}) {
    final since = (now ?? DateTime.now()).subtract(const Duration(days: 7));
    double? round1(double? v) => v == null ? null : double.parse(v.toStringAsFixed(1));
    return {
      'weekly': {
        'restingHr': round1(weekly.restingHr),
        'restingHrChange': round1(weekly.restingHrChange),
        'activityChangePct': round1(weekly.activityChangePct),
        'alerts': weekly.alerts,
      },
      'journal': [
        for (final e in entries.where((e) => e.createdAt.isAfter(since)).take(10))
          {
            'date': DailySummary.dayKey(e.createdAt),
            'kind': e.kind,
            'tag': e.kind == JournalEntry.kindWeight ? '${e.weightKg?.toStringAsFixed(1)} kg' : e.tag,
            'text': e.text.length > 200 ? e.text.substring(0, 200) : e.text,
          },
      ],
    };
  }
}
