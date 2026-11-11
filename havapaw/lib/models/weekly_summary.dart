// This week vs last week, from daily summaries, alerts and journal entries
import 'daily_summary.dart';
import 'journal_entry.dart';

class WeeklySummary {
  final double? restingHr;
  final double? previousRestingHr;
  final double? avgSteps;
  final double? previousAvgSteps;
  final int alerts;
  final int checkIns;
  final int notes;
  final int daysWithData;

  const WeeklySummary({
    this.restingHr,
    this.previousRestingHr,
    this.avgSteps,
    this.previousAvgSteps,
    this.alerts = 0,
    this.checkIns = 0,
    this.notes = 0,
    this.daysWithData = 0,
  });

  // Percentage change in activity vs last week, null if either week has no steps
  double? get activityChangePct {
    if (avgSteps == null || previousAvgSteps == null || previousAvgSteps == 0) return null;
    return (avgSteps! - previousAvgSteps!) / previousAvgSteps! * 100;
  }

  double? get restingHrChange =>
      restingHr != null && previousRestingHr != null ? restingHr! - previousRestingHr! : null;

  static WeeklySummary build({
    required List<DailySummary> summaries,
    required List<DateTime> alertTimes,
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    final today = DateTime((now ?? DateTime.now()).year, (now ?? DateTime.now()).month, (now ?? DateTime.now()).day);
    final weekStart = today.subtract(const Duration(days: 6));
    final prevStart = weekStart.subtract(const Duration(days: 7));

    bool inWeek(DateTime d) => !d.isBefore(weekStart) && !d.isAfter(today.add(const Duration(days: 1)));
    bool inPrev(DateTime d) => !d.isBefore(prevStart) && d.isBefore(weekStart);

    final thisWeek = <DailySummary>[];
    final lastWeek = <DailySummary>[];
    for (final s in summaries) {
      final d = DateTime.tryParse(s.date);
      if (d == null) continue;
      if (inWeek(d)) thisWeek.add(s);
      if (inPrev(d)) lastWeek.add(s);
    }

    double? restingHr(List<DailySummary> days) {
      final v = [for (final s in days) if (s.restingHeartRate != null) s.restingHeartRate!];
      return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    }

    double? steps(List<DailySummary> days) {
      final v = [for (final s in days) if (s.avgStepsPerReading != null) s.avgStepsPerReading!];
      return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    }

    final weekEntries = entries.where((e) => inWeek(e.createdAt.toLocal()));
    return WeeklySummary(
      restingHr: restingHr(thisWeek),
      previousRestingHr: restingHr(lastWeek),
      avgSteps: steps(thisWeek),
      previousAvgSteps: steps(lastWeek),
      alerts: alertTimes.where((t) => inWeek(t.toLocal())).length,
      checkIns: weekEntries.where((e) => e.kind == JournalEntry.kindCheckIn).length,
      notes: weekEntries.where((e) => e.kind != JournalEntry.kindCheckIn).length,
      daysWithData: thisWeek.length,
    );
  }
}
