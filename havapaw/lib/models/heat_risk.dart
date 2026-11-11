// Walk safety from the local "feels like" temperature
import 'pet.dart';
import '../services/health_intelligence_service.dart';

enum HeatLevel { low, moderate, high, extreme }

class HeatRisk {
  final HeatLevel level;
  final double feelsLikeC;
  final double airTempC;
  final int humidity;
  final bool sensitivePet;

  const HeatRisk({
    required this.level,
    required this.feelsLikeC,
    required this.airTempC,
    required this.humidity,
    required this.sensitivePet,
  });

  // Flat-faced breeds overheat more easily
  static const _flatFaced = [
    'pug', 'bulldog', 'shih tzu', 'boxer', 'pekingese', 'boston terrier',
    'french bulldog', 'cavalier', 'lhasa', 'persian', 'himalayan', 'exotic',
  ];

  static bool isSensitive(Pet pet) {
    final breed = pet.breed.toLowerCase();
    final age = HealthIntelligenceService.calculatePetAge(pet.birthday);
    return age > 8 || _flatFaced.any(breed.contains);
  }

  static HeatRisk assess({required double feelsLikeC, required double airTempC, required int humidity, required Pet pet}) {
    var level = feelsLikeC >= 38
        ? HeatLevel.extreme
        : feelsLikeC >= 32
            ? HeatLevel.high
            : feelsLikeC >= 28
                ? HeatLevel.moderate
                : HeatLevel.low;
    final sensitive = isSensitive(pet);
    if (sensitive && level != HeatLevel.extreme) level = HeatLevel.values[level.index + 1];
    return HeatRisk(level: level, feelsLikeC: feelsLikeC, airTempC: airTempC, humidity: humidity, sensitivePet: sensitive);
  }
}
