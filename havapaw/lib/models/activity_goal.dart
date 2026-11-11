// Daily active-minutes goal and streak (same goal as rules.js activityGoalMinutes)
import 'daily_summary.dart';
import 'pet.dart';
import '../services/health_intelligence_service.dart';

class ActivityGoal {
  static int goalMinutes(Pet pet) {
    if (pet.type.toLowerCase() == 'cat') return 20;
    final age = HealthIntelligenceService.calculatePetAge(pet.birthday);
    var goal = pet.weight < 12 ? 40 : pet.weight < 55 ? 60 : 45;
    if (age < 1 || age > 8) goal = goal < 30 ? goal : 30;
    return goal;
  }

  static int todayMinutes(List<DailySummary> summaries, {DateTime? now}) {
    final key = DailySummary.dayKey(now ?? DateTime.now());
    for (final s in summaries) {
      if (s.date == key) return s.activeMinutes;
    }
    return 0;
  }

  // Days in a row the goal was met, counting back from today (or yesterday if today is not done yet)
  static int streak(List<DailySummary> summaries, int goal, {DateTime? now}) {
    final byDay = {for (final s in summaries) s.date: s.activeMinutes};
    var day = now ?? DateTime.now();
    if ((byDay[DailySummary.dayKey(day)] ?? 0) < goal) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while ((byDay[DailySummary.dayKey(day)] ?? 0) >= goal) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }
}
