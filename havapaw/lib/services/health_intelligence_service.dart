import 'package:flutter/foundation.dart';
import '../models/collar_data.dart';
import '../models/pet.dart';

// Health status classification based on research proposal
enum HealthStatus {
  normal,
  warning,
  critical,
}

// Alert types for context-aware health intelligence
enum HealthAlertType {
  highHeartRate, // Heart rate > 140
  stressWarning, // High heart rate + low movement
  lowActivity, // Activity < 50% of 3-day average
  highTemperature, // Temperature above threshold
  dehydrationRisk, // Predictive analysis
}

class HealthAlert {
  final HealthAlertType type;
  final String message;
  final String recommendation;
  final DateTime timestamp;
  final double severity; // 0.0 to 1.0

  HealthAlert({
    required this.type,
    required this.message,
    required this.recommendation,
    required this.timestamp,
    required this.severity,
  });
}

// Service for Context-Aware Health Intelligence and Behavior Pattern Learning
class HealthIntelligenceService {
  // Thresholds based on research (can be customized per pet)
  static const double highHeartRateThreshold = 140.0; // BPM
  static const double highTemperatureThreshold = 39.5; // Celsius
  static const double lowActivityThreshold = 0.5; // 50% of normal
  static const int learningPeriodDays = 3; // 3-day rolling average

  // Breed-specific heart rate ranges (BPM)
  static const Map<String, Map<String, double>> breedHeartRateRanges = {
    'dog': {'min': 60.0, 'max': 140.0},
    'cat': {'min': 140.0, 'max': 220.0},
  };

  /// Maps a dog's weight to the size class used by the training pipeline
  /// (havapaw_ml/data/generate_dataset.py). Boundaries mirror common breed
  /// weight ranges: toy (Chihuahua-like) through giant (Great Dane-like).
  static String dogSizeClass(double weight) {
    if (weight < 5) return 'toy';
    if (weight < 12) return 'small';
    if (weight < 30) return 'medium';
    if (weight < 55) return 'large';
    return 'giant';
  }

  /// Population-level RESTING heart rate baseline (the pet's expected normal
  /// HR at rest) -- distinct from getIndividualizedHeartRateThreshold, which
  /// is the alert CEILING. Mirrors resting_hr_baseline() in
  /// havapaw_ml/data/generate_dataset.py exactly, since the ML model's
  /// hr_deviation_pct feature was trained against this resting baseline, not
  /// the ceiling. Used as the Bayesian prior in BaselineCalibrationService.
  static double getPopulationRestingHeartRateBaseline(Pet pet) {
    final age = calculatePetAge(pet.birthday);
    final petType = pet.type.toLowerCase();

    double base;
    if (petType == 'cat') {
      base = 170.0;
    } else {
      final sizeClass = dogSizeClass(pet.weight);
      base = switch (sizeClass) {
        'toy' => 135.0,
        'small' => 110.0,
        'medium' => 90.0,
        'large' => 75.0,
        'giant' => 65.0,
        _ => 90.0,
      };
    }

    if (age < 1) {
      base += 15; // puppies/kittens run hotter
    } else if (age > 8) {
      base -= 8;
    }

    return base.clamp(45.0, 210.0);
  }

  // Calculate Activity Index from accelerometer data (A(t) = sqrt(X² + Y² + Z²))
  static double calculateActivityIndex(double? x, double? y, double? z) {
    if (x == null || y == null || z == null) return 0.0;
    return (x * x + y * y + z * z).toDouble();
  }

  // Calculate age from birthday
  static int calculatePetAge(String birthday) {
    try {
      final birthDate = DateTime.parse(birthday);
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0;
    }
  }

  // Get individualized heart rate threshold based on pet profile
  static double getIndividualizedHeartRateThreshold(Pet pet) {
    final age = calculatePetAge(pet.birthday);
    final weight = pet.weight;
    final petType = pet.type.toLowerCase();

    // Base thresholds
    final baseRange = breedHeartRateRanges[petType] ?? breedHeartRateRanges['dog'];
    double maxThreshold = baseRange?['max'] ?? highHeartRateThreshold;

    // Adjust for age (older pets may have lower threshold)
    if (age > 8) {
      maxThreshold -= 10;
    } else if (age < 2) {
      maxThreshold += 10;
    }

    // Adjust for weight (obesity affects heart rate)
    if (weight > 30) {
      maxThreshold -= 5;
    }

    return maxThreshold.clamp(60.0, 220.0);
  }

  // Get individualized temperature threshold based on pet profile
  static double getIndividualizedTemperatureThreshold(Pet pet) {
    final age = calculatePetAge(pet.birthday);
    final petType = pet.type.toLowerCase();

    double threshold = highTemperatureThreshold;

    // Older pets may have lower baseline temperature
    if (age > 10) {
      threshold -= 0.3;
    }

    // Cats have slightly higher normal temperature
    if (petType == 'cat') {
      threshold += 0.5;
    }

    return threshold.clamp(38.0, 41.0);
  }

  // Context-Aware Health Analysis with individualized baselines
  static HealthStatus analyzeHealthStatus(CollarData data, Pet pet) {
    final heartRate = data.heartRate?.toDouble() ?? 0.0;
    final temperature = data.temperature ?? 0.0;
    final steps = data.steps ?? 0;

    // Get individualized thresholds
    final maxHeartRate = getIndividualizedHeartRateThreshold(pet);
    final maxTemperature = getIndividualizedTemperatureThreshold(pet);

    // Critical conditions
    if (heartRate > maxHeartRate + 20 || temperature > maxTemperature + 1.0) {
      return HealthStatus.critical;
    }

    // Warning conditions
    if (heartRate > maxHeartRate || temperature > maxTemperature) {
      return HealthStatus.warning;
    }

    return HealthStatus.normal;
  }

  // Stress Detection with individualized baselines
  static HealthAlert? detectStressWarning(CollarData data, Pet pet) {
    final heartRate = data.heartRate?.toDouble() ?? 0.0;
    final steps = data.steps ?? 0;

    // Get individualized threshold
    final maxHeartRate = getIndividualizedHeartRateThreshold(pet);

    // Stress condition: High heart rate + low movement
    if (heartRate > maxHeartRate && steps < 100) {
      return HealthAlert(
        type: HealthAlertType.stressWarning,
        message: 'Stress detected: High heart rate during low activity',
        recommendation: 'Check on your pet. This may indicate anxiety or discomfort.',
        timestamp: DateTime.now(),
        severity: 0.7,
      );
    }

    return null;
  }

  // High Heart Rate Alert with individualized baselines
  static HealthAlert? detectHighHeartRate(CollarData data, Pet pet) {
    final heartRate = data.heartRate?.toDouble() ?? 0.0;

    // Get individualized threshold
    final maxHeartRate = getIndividualizedHeartRateThreshold(pet);

    if (heartRate > maxHeartRate) {
      return HealthAlert(
        type: HealthAlertType.highHeartRate,
        message: 'High heart rate detected: ${heartRate.toStringAsFixed(0)} BPM',
        recommendation: 'Monitor your pet. Consider veterinary consultation if elevated.',
        timestamp: DateTime.now(),
        severity: heartRate > maxHeartRate + 20 ? 0.9 : 0.6,
      );
    }

    return null;
  }

  // High Temperature Alert with individualized baselines
  static HealthAlert? detectHighTemperature(CollarData data, Pet pet) {
    final temperature = data.temperature ?? 0.0;

    // Get individualized threshold
    final maxTemperature = getIndividualizedTemperatureThreshold(pet);

    if (temperature > maxTemperature) {
      return HealthAlert(
        type: HealthAlertType.highTemperature,
        message: 'High temperature detected: ${temperature.toStringAsFixed(1)}°C',
        recommendation: 'Check for signs of heat stress. Provide water and cool environment.',
        timestamp: DateTime.now(),
        severity: temperature > maxTemperature + 1.0 ? 0.9 : 0.6,
      );
    }

    return null;
  }

  // Behavior Pattern Learning: Calculate 3-day activity average
  static double calculateThreeDayAverage(List<CollarData> recentData) {
    if (recentData.isEmpty) return 0.0;

    // Group data by day
    final Map<String, int> dailySteps = {};
    for (final data in recentData) {
      final dateKey = '${data.timestamp.year}-${data.timestamp.month}-${data.timestamp.day}';
      dailySteps[dateKey] = (dailySteps[dateKey] ?? 0) + (data.steps ?? 0);
    }

    // Get last 3 days of data
    final sortedDays = dailySteps.keys.toList()..sort();
    final recentDays = sortedDays.take(learningPeriodDays).toList();

    if (recentDays.isEmpty) return 0.0;

    // Calculate average
    int totalSteps = 0;
    for (final day in recentDays) {
      totalSteps += dailySteps[day] ?? 0;
    }

    return totalSteps / recentDays.length;
  }

  // Low Activity Warning: Today's activity < 50% of 3-day average
  static HealthAlert? detectLowActivity(
    CollarData currentData,
    List<CollarData> historicalData,
  ) {
    final todaySteps = currentData.steps ?? 0;
    final threeDayAverage = calculateThreeDayAverage(historicalData);

    if (threeDayAverage > 0 && todaySteps < threeDayAverage * lowActivityThreshold) {
      final percentage = (todaySteps / threeDayAverage * 100).toStringAsFixed(0);
      return HealthAlert(
        type: HealthAlertType.lowActivity,
        message: 'Low activity detected: $percentage% of normal',
        recommendation: 'Activity is significantly lower than usual. Monitor for lethargy or illness.',
        timestamp: DateTime.now(),
        severity: 0.5,
      );
    }

    return null;
  }

  // Generate all health alerts for current data
  static List<HealthAlert> generateHealthAlerts(
    CollarData currentData,
    Pet pet,
    List<CollarData> historicalData,
  ) {
    final alerts = <HealthAlert>[];

    // Context-aware alerts
    final stressAlert = detectStressWarning(currentData, pet);
    if (stressAlert != null) alerts.add(stressAlert);

    final highHeartRateAlert = detectHighHeartRate(currentData, pet);
    if (highHeartRateAlert != null) alerts.add(highHeartRateAlert);

    final highTempAlert = detectHighTemperature(currentData, pet);
    if (highTempAlert != null) alerts.add(highTempAlert);

    // Behavior pattern learning alert
    final lowActivityAlert = detectLowActivity(currentData, historicalData);
    if (lowActivityAlert != null) alerts.add(lowActivityAlert);

    return alerts;
  }

  // Predictive Health Analysis (future enhancement)
  static List<HealthAlert> predictiveAnalysis(
    List<CollarData> recentData,
    Pet pet,
  ) {
    final alerts = <HealthAlert>[];

    // Analyze trends over time
    if (recentData.length < 5) return alerts;

    // Check for decreasing activity trend (possible fatigue/illness)
    final recentSteps = recentData.take(5).map((d) => d.steps ?? 0).toList();
    final trendDecreasing = _isDecreasingTrend(recentSteps);

    if (trendDecreasing) {
      alerts.add(HealthAlert(
        type: HealthAlertType.dehydrationRisk,
        message: 'Activity decreasing over time',
        recommendation: 'Monitor for fatigue or illness. Ensure adequate hydration.',
        timestamp: DateTime.now(),
        severity: 0.4,
      ));
    }

    return alerts;
  }

  // Helper to detect decreasing trend
  static bool _isDecreasingTrend(List<int> values) {
    if (values.length < 2) return false;
    int decreasingCount = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] < values[i - 1]) decreasingCount++;
    }
    return decreasingCount >= values.length / 2;
  }
}
