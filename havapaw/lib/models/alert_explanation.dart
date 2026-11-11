// "Why this status?": each reading compared with the pet's own limits and baseline
import 'collar_data.dart';
import 'pet.dart';
import '../services/health_intelligence_service.dart';

enum FactorStatus { normal, high, low, info }

class ExplanationFactor {
  final String key; // translation key for the label
  final String value; // what the collar measured
  final String reference; // translation key describing the comparison
  final Map<String, String> args; // named args for [reference]
  final FactorStatus status;

  const ExplanationFactor({
    required this.key,
    required this.value,
    required this.reference,
    this.args = const {},
    required this.status,
  });
}

class AlertExplanation {
  static const double baselineDeviation = 0.35; // same as rules.js
  static const double lowActivityRatio = 0.65; // same as HealthIntelligenceService
  static const double lowSpo2 = 95;

  static List<ExplanationFactor> build(
    CollarData reading,
    Pet pet, {
    double? hrBaseline,
    double? activityRatio,
  }) {
    final out = <ExplanationFactor>[];
    final name = pet.name;

    final hr = reading.heartRate;
    if (hr != null) {
      final limit = HealthIntelligenceService.getIndividualizedHeartRateThreshold(pet);
      if (hrBaseline != null && hrBaseline > 0) {
        final pct = (hr - hrBaseline) / hrBaseline;
        out.add(ExplanationFactor(
          key: 'why_heart_rate',
          value: '$hr bpm',
          reference: 'why_vs_baseline',
          args: {
            'pct': '${pct >= 0 ? '+' : ''}${(pct * 100).round()}%',
            'pet': name,
            'baseline': hrBaseline.round().toString(),
          },
          status: hr > limit || pct >= baselineDeviation
              ? FactorStatus.high
              : pct <= -baselineDeviation
                  ? FactorStatus.low
                  : FactorStatus.normal,
        ));
      } else {
        out.add(ExplanationFactor(
          key: 'why_heart_rate',
          value: '$hr bpm',
          reference: 'why_vs_limit',
          args: {'limit': '${limit.round()} bpm'},
          status: hr > limit ? FactorStatus.high : FactorStatus.normal,
        ));
      }
    }

    final temp = reading.temperature;
    if (temp != null) {
      final limit = HealthIntelligenceService.getIndividualizedTemperatureThreshold(pet);
      out.add(ExplanationFactor(
        key: 'why_temperature',
        value: '${temp.toStringAsFixed(1)} °C',
        reference: 'why_vs_limit',
        args: {'limit': '${limit.toStringAsFixed(1)} °C'},
        status: temp > limit ? FactorStatus.high : FactorStatus.normal,
      ));
    }

    final steps = reading.steps;
    if (steps != null) {
      out.add(ExplanationFactor(
        key: 'why_movement',
        value: '$steps',
        reference: steps > 150 ? 'why_moving' : 'why_still',
        status: FactorStatus.info,
      ));
    }

    if (activityRatio != null) {
      out.add(ExplanationFactor(
        key: 'why_activity',
        value: '${(activityRatio * 100).round()}%',
        reference: 'why_vs_3day',
        status: activityRatio < lowActivityRatio ? FactorStatus.low : FactorStatus.normal,
      ));
    }

    final spo2 = reading.bloodOxygen;
    if (spo2 != null) {
      out.add(ExplanationFactor(
        key: 'why_spo2',
        value: '${spo2.round()}%',
        reference: 'why_vs_limit_low',
        args: {'limit': '${lowSpo2.round()}%'},
        status: spo2 < lowSpo2 ? FactorStatus.low : FactorStatus.normal,
      ));
    }
    return out;
  }

  // Short headline: the factors that are out of range, or that all is normal
  static List<ExplanationFactor> flagged(List<ExplanationFactor> factors) =>
      factors.where((f) => f.status == FactorStatus.high || f.status == FactorStatus.low).toList();
}
