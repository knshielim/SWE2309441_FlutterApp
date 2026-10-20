import 'collar_data.dart';

class DailySummary {
  static const int restingStepsCutoff = 150;

  final String date; // local day, YYYY-MM-DD
  final int stepsSum;
  final int stepsN;
  final double restHrSum;
  final int restHrN;

  const DailySummary({
    required this.date,
    this.stepsSum = 0,
    this.stepsN = 0,
    this.restHrSum = 0,
    this.restHrN = 0,
  });

  // Average steps per reading (the collar counts steps over its last 5 minutes).
  double? get avgStepsPerReading => stepsN > 0 ? stepsSum / stepsN : null;

  double? get restingHeartRate => restHrN > 0 ? restHrSum / restHrN : null;

  factory DailySummary.fromMap(Map<String, dynamic> map, String docId) {
    return DailySummary(
      date: (map['date'] as String?) ?? docId,
      stepsSum: (map['stepsSum'] as num?)?.toInt() ?? 0,
      stepsN: (map['stepsN'] as num?)?.toInt() ?? 0,
      restHrSum: (map['restHrSum'] as num?)?.toDouble() ?? 0,
      restHrN: (map['restHrN'] as num?)?.toInt() ?? 0,
    );
  }

  static String dayKey(DateTime t) {
    final d = t.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static List<DailySummary> fromReadings(Iterable<CollarData> readings) {
    final seen = <String>{};
    final steps = <String, List<int>>{};
    final restHr = <String, List<double>>{};
    for (final r in readings) {
      if (r.id != null && !seen.add(r.id!)) continue;
      final day = dayKey(r.timestamp);
      if (r.steps != null) steps.putIfAbsent(day, () => []).add(r.steps!);
      final hr = r.heartRate;
      if (hr != null && (r.steps ?? 0) <= restingStepsCutoff) {
        restHr.putIfAbsent(day, () => []).add(hr.toDouble());
      }
    }
    final days = {...steps.keys, ...restHr.keys}.toList()..sort();
    return [
      for (final day in days)
        DailySummary(
          date: day,
          stepsSum: (steps[day] ?? const []).fold(0, (a, b) => a + b),
          stepsN: steps[day]?.length ?? 0,
          restHrSum: (restHr[day] ?? const []).fold(0.0, (a, b) => a + b),
          restHrN: restHr[day]?.length ?? 0,
        ),
    ];
  }
}
