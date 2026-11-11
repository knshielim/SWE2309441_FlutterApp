// Decides when to ask the owner what the pet is doing
import 'collar_data.dart';
import 'pet.dart';
import '../services/health_intelligence_service.dart';

enum SpikeReason { heartRate, temperature }

class SpikeCheck {
  // Same limit as the server's baseline deviation alert (rules.js)
  static const double baselineDeviation = 0.35;
  static const Duration maxAge = Duration(minutes: 30);

  // Returns why this reading needs a check-in, or null if it looks normal or is old
  static SpikeReason? reasonFor(CollarData reading, Pet pet, {double? hrBaseline, DateTime? now}) {
    final age = (now ?? DateTime.now()).difference(reading.timestamp);
    if (age > maxAge || age.isNegative && age.abs() > const Duration(minutes: 5)) return null;

    final temp = reading.temperature;
    if (temp != null && temp > HealthIntelligenceService.getIndividualizedTemperatureThreshold(pet)) {
      return SpikeReason.temperature;
    }

    final hr = reading.heartRate?.toDouble();
    if (hr == null) return null;
    if (hr > HealthIntelligenceService.getIndividualizedHeartRateThreshold(pet)) return SpikeReason.heartRate;
    if (hrBaseline != null && hrBaseline > 0 && (hr - hrBaseline) / hrBaseline >= baselineDeviation) {
      return SpikeReason.heartRate;
    }
    return null;
  }

  // What the app says after the owner answers
  static String adviceKeyFor(String tag, SpikeReason reason) {
    switch (tag) {
      case 'playing':
        return reason == SpikeReason.temperature ? 'checkin_advice_playing_temp' : 'checkin_advice_playing';
      case 'resting':
        return 'checkin_advice_resting';
      case 'stressed':
        return 'checkin_advice_stressed';
      case 'ate':
        return 'checkin_advice_ate';
      default:
        return 'checkin_advice_unsure';
    }
  }
}
