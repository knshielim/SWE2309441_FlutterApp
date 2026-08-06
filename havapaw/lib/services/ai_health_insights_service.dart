import 'package:flutter/foundation.dart';
import '../models/collar_data.dart';
import '../models/pet.dart';
import 'health_intelligence_service.dart';

// AI-generated insight categories
enum InsightCategory {
  health,
  behavior,
  nutrition,
  exercise,
  general,
}

class HealthInsight {
  final String title;
  final String description;
  final InsightCategory category;
  final double confidence; // 0.0 to 1.0
  final List<String> recommendations;
  final DateTime generatedAt;

  HealthInsight({
    required this.title,
    required this.description,
    required this.category,
    required this.confidence,
    required this.recommendations,
    required this.generatedAt,
  });
}

// Service for AI-powered health insights using LLM-like analysis
class AIHealthInsightsService {
  // Generate comprehensive health insights using rule-based AI
  static Future<List<HealthInsight>> generateHealthInsights(
    Pet pet,
    List<CollarData> recentData,
    List<CollarData> historicalData,
  ) async {
    final insights = <HealthInsight>[];

    if (recentData.isEmpty) return insights;

    // Analyze heart rate patterns
    insights.addAll(_analyzeHeartRatePatterns(pet, recentData));

    // Analyze activity patterns
    insights.addAll(_analyzeActivityPatterns(pet, recentData, historicalData));

    // Analyze temperature patterns
    insights.addAll(_analyzeTemperaturePatterns(pet, recentData));

    // Analyze sleep/rest patterns
    insights.addAll(_analyzeRestPatterns(pet, recentData));

    // Generate exercise recommendations
    insights.addAll(_generateExerciseRecommendations(pet, recentData));

    // Generate nutrition insights
    insights.addAll(_generateNutritionInsights(pet, recentData));

    // Sort by confidence
    insights.sort((a, b) => b.confidence.compareTo(a.confidence));

    return insights;
  }

  // Analyze heart rate patterns for anomalies
  static List<HealthInsight> _analyzeHeartRatePatterns(
    Pet pet,
    List<CollarData> data,
  ) {
    final insights = <HealthInsight>[];

    if (data.length < 5) return insights;

    final heartRates = data.map((d) => d.heartRate?.toDouble() ?? 0.0).toList();
    final avgHeartRate = heartRates.reduce((a, b) => a + b) / heartRates.length;
    final maxHeartRate = heartRates.reduce((a, b) => a > b ? a : b);
    final minHeartRate = heartRates.reduce((a, b) => a < b ? a : b);
    final variance = _calculateVariance(heartRates, avgHeartRate);

    // High heart rate variability
    if (variance > 100) {
      insights.add(HealthInsight(
        title: 'High Heart Rate Variability Detected',
        description: 'Your pet\'s heart rate shows significant fluctuations (${variance.toStringAsFixed(1)} variance). This could indicate stress, excitement, or potential health concerns.',
        category: InsightCategory.health,
        confidence: 0.75,
        recommendations: [
          'Monitor for signs of stress or anxiety',
          'Check if environmental factors are causing excitement',
          'Consider consulting a vet if pattern persists',
        ],
        generatedAt: DateTime.now(),
      ));
    }

    // Consistently elevated heart rate
    if (avgHeartRate > HealthIntelligenceService.getIndividualizedHeartRateThreshold(pet)) {
      insights.add(HealthInsight(
        title: 'Elevated Average Heart Rate',
        description: 'Average heart rate (${avgHeartRate.toStringAsFixed(0)} BPM) is above normal range for ${pet.name}. This may indicate underlying health issues.',
        category: InsightCategory.health,
        confidence: 0.85,
        recommendations: [
          'Schedule a veterinary check-up',
          'Monitor for other symptoms like lethargy or loss of appetite',
          'Ensure adequate rest periods',
        ],
        generatedAt: DateTime.now(),
      ));
    }

    // Bradycardia (low heart rate)
    if (avgHeartRate < 60 && pet.type.toLowerCase() == 'dog') {
      insights.add(HealthInsight(
        title: 'Low Heart Rate (Bradycardia)',
        description: 'Average heart rate (${avgHeartRate.toStringAsFixed(0)} BPM) is below normal range. This could indicate heart issues or athletic conditioning.',
        category: InsightCategory.health,
        confidence: 0.80,
        recommendations: [
          'Consult with a veterinarian',
          'Check for signs of weakness or fainting',
          'Review medications that might affect heart rate',
        ],
        generatedAt: DateTime.now(),
      ));
    }

    return insights;
  }

  // Analyze activity patterns
  static List<HealthInsight> _analyzeActivityPatterns(
    Pet pet,
    List<CollarData> recentData,
    List<CollarData> historicalData,
  ) {
    final insights = <HealthInsight>[];

    if (recentData.isEmpty) return insights;

    final recentSteps = recentData.map((d) => d.steps ?? 0).toList();
    final avgRecentSteps = recentSteps.reduce((a, b) => a + b) / recentSteps.length;

    // Compare with historical data
    if (historicalData.isNotEmpty) {
      final historicalSteps = historicalData.map((d) => d.steps ?? 0).toList();
      final avgHistoricalSteps = historicalSteps.reduce((a, b) => a + b) / historicalSteps.length;

      final changePercentage = ((avgRecentSteps - avgHistoricalSteps) / avgHistoricalSteps) * 100;

      if (changePercentage < -30) {
        insights.add(HealthInsight(
          title: 'Significant Activity Decrease',
          description: 'Activity has decreased by ${changePercentage.abs().toStringAsFixed(0)}% compared to historical average. This could indicate illness, injury, or seasonal changes.',
          category: InsightCategory.behavior,
          confidence: 0.85,
          recommendations: [
            'Check for signs of pain or discomfort',
            'Review recent changes in environment or routine',
            'Consider veterinary examination if decrease persists',
          ],
          generatedAt: DateTime.now(),
        ));
      } else if (changePercentage > 50) {
        insights.add(HealthInsight(
          title: 'Increased Activity Level',
          description: 'Activity has increased by ${changePercentage.toStringAsFixed(0)}% compared to historical average. Ensure adequate rest and hydration.',
          category: InsightCategory.exercise,
          confidence: 0.70,
          recommendations: [
            'Monitor for signs of overexertion',
            'Ensure proper hydration',
            'Provide adequate rest periods',
          ],
          generatedAt: DateTime.now(),
        ));
      }
    }

    // Sedentary behavior detection
    if (avgRecentSteps < 1000) {
      insights.add(HealthInsight(
        title: 'Low Activity Level',
        description: 'Average daily steps (${avgRecentSteps.toStringAsFixed(0)}) is very low. Regular exercise is important for pet health.',
        category: InsightCategory.exercise,
        confidence: 0.90,
        recommendations: [
          'Increase daily walks gradually',
          'Engage in interactive play sessions',
          'Consider puzzle toys for mental stimulation',
        ],
        generatedAt: DateTime.now(),
      ));
    }

    return insights;
  }

  // Analyze temperature patterns
  static List<HealthInsight> _analyzeTemperaturePatterns(
    Pet pet,
    List<CollarData> data,
  ) {
    final insights = <HealthInsight>[];

    if (data.length < 3) return insights;

    final temperatures = data.map((d) => d.temperature ?? 0.0).toList();
    final avgTemp = temperatures.reduce((a, b) => a + b) / temperatures.length;
    final maxTemp = temperatures.reduce((a, b) => a > b ? a : b);

    // Elevated temperature
    if (avgTemp > HealthIntelligenceService.getIndividualizedTemperatureThreshold(pet)) {
      insights.add(HealthInsight(
        title: 'Elevated Body Temperature',
        description: 'Average temperature (${avgTemp.toStringAsFixed(1)}°C) is above normal range. This could indicate fever or heat stress.',
        category: InsightCategory.health,
        confidence: 0.80,
        recommendations: [
          'Check for signs of fever or infection',
          'Ensure cool environment and hydration',
          'Consult veterinarian if temperature remains elevated',
        ],
        generatedAt: DateTime.now(),
      ));
    }

    // Temperature fluctuations
    final tempVariance = _calculateVariance(temperatures, avgTemp);
    if (tempVariance > 0.5) {
      insights.add(HealthInsight(
        title: 'Temperature Fluctuations',
        description: 'Body temperature shows significant fluctuations (${tempVariance.toStringAsFixed(2)} variance). Monitor for patterns.',
        category: InsightCategory.health,
        confidence: 0.65,
        recommendations: [
          'Track temperature at different times of day',
          'Note environmental conditions',
          'Consult vet if fluctuations persist',
        ],
        generatedAt: DateTime.now(),
      ));
    }

    return insights;
  }

  // Analyze rest/sleep patterns
  static List<HealthInsight> _analyzeRestPatterns(
    Pet pet,
    List<CollarData> data,
  ) {
    final insights = <HealthInsight>[];

    if (data.length < 5) return insights;

    // Estimate rest periods based on low activity
    final lowActivityCount = data.where((d) => (d.steps ?? 0) < 50).length;
    final restPercentage = (lowActivityCount / data.length) * 100;

    if (restPercentage > 80) {
      insights.add(HealthInsight(
        title: 'Excessive Rest/Lethargy',
        description: 'Pet is resting ${restPercentage.toStringAsFixed(0)}% of the time. This could indicate illness, depression, or aging.',
        category: InsightCategory.behavior,
        confidence: 0.75,
        recommendations: [
          'Check for signs of illness or pain',
          'Evaluate environmental factors',
          'Consult veterinarian if lethargy persists',
        ],
        generatedAt: DateTime.now(),
      ));
    } else if (restPercentage < 20) {
      insights.add(HealthInsight(
        title: 'Insufficient Rest',
        description: 'Pet is only resting ${restPercentage.toStringAsFixed(0)}% of the time. Adequate rest is crucial for health.',
        category: InsightCategory.behavior,
        confidence: 0.70,
        recommendations: [
          'Ensure quiet, comfortable sleeping area',
          'Maintain consistent sleep schedule',
          'Reduce stimulation during rest periods',
        ],
        generatedAt: DateTime.now(),
      ));
    }

    return insights;
  }

  // Generate exercise recommendations
  static List<HealthInsight> _generateExerciseRecommendations(
    Pet pet,
    List<CollarData> data,
  ) {
    final insights = <HealthInsight>[];

    if (data.isEmpty) return insights;

    final avgSteps = data.map((d) => d.steps ?? 0).reduce((a, b) => a + b) / data.length;
    final age = HealthIntelligenceService.calculatePetAge(pet.birthday);
    final weight = pet.weight;

    // Age-appropriate exercise recommendations
    if (age < 1) {
      insights.add(HealthInsight(
        title: 'Puppy Exercise Guidelines',
        description: 'Young pets need controlled exercise to protect developing joints. Short, frequent sessions are best.',
        category: InsightCategory.exercise,
        confidence: 0.95,
        recommendations: [
          'Limit exercise to 5 minutes per month of age, twice daily',
          'Avoid high-impact activities like jumping',
          'Focus on mental stimulation and socialization',
        ],
        generatedAt: DateTime.now(),
      ));
    } else if (age > 8) {
      insights.add(HealthInsight(
        title: 'Senior Pet Exercise',
        description: 'Older pets benefit from gentle, regular exercise to maintain mobility and muscle tone.',
        category: InsightCategory.exercise,
        confidence: 0.90,
        recommendations: [
          'Focus on low-impact activities like swimming',
          'Shorter, more frequent walks are better than long sessions',
          'Include gentle stretching and flexibility exercises',
        ],
        generatedAt: DateTime.now(),
      ));
    }

    // Weight-based exercise recommendations
    if (weight > 30) {
      insights.add(HealthInsight(
        title: 'Weight Management Exercise',
        description: 'For overweight pets, gradual increase in activity combined with diet control is recommended.',
        category: InsightCategory.exercise,
        confidence: 0.85,
        recommendations: [
          'Start with 10-15 minute walks, gradually increasing duration',
          'Swimming is excellent low-impact exercise',
          'Monitor for signs of overexertion',
        ],
        generatedAt: DateTime.now(),
      ));
    }

    return insights;
  }

  // Generate nutrition insights
  static List<HealthInsight> _generateNutritionInsights(
    Pet pet,
    List<CollarData> data,
  ) {
    final insights = <HealthInsight>[];

    final avgCalories = data.isNotEmpty
        ? data.map((d) => d.calories ?? 0).reduce((a, b) => a + b) / data.length
        : 0.0;
    final weight = pet.weight;

    // Calorie needs estimation
    final estimatedCalories = _estimateDailyCalories(pet);
    
    if (avgCalories > 0 && estimatedCalories > 0) {
      final ratio = avgCalories / estimatedCalories;

      if (ratio > 1.3) {
        insights.add(HealthInsight(
          title: 'High Calorie Intake',
          description: 'Calorie intake appears to be ${((ratio - 1) * 100).toStringAsFixed(0)}% above estimated needs. This may contribute to weight gain.',
          category: InsightCategory.nutrition,
          confidence: 0.75,
        recommendations: [
          'Review portion sizes and feeding schedule',
          'Consider lower-calorie food options',
          'Increase exercise to match calorie intake',
        ],
        generatedAt: DateTime.now(),
        ));
      } else if (ratio < 0.7) {
        insights.add(HealthInsight(
          title: 'Low Calorie Intake',
          description: 'Calorie intake appears to be ${((1 - ratio) * 100).toStringAsFixed(0)}% below estimated needs. Ensure adequate nutrition.',
          category: InsightCategory.nutrition,
          confidence: 0.70,
          recommendations: [
          'Review food quality and portion sizes',
          'Consult veterinarian about nutritional needs',
          'Monitor for weight loss or lethargy',
        ],
        generatedAt: DateTime.now(),
        ));
      }
    }

    return insights;
  }

  // Estimate daily calorie needs based on pet profile
  static double _estimateDailyCalories(Pet pet) {
    final weight = pet.weight;
    final age = HealthIntelligenceService.calculatePetAge(pet.birthday);
    final petType = pet.type.toLowerCase();

    // RER (Resting Energy Rate) calculation
    double rer;
    if (petType == 'cat') {
      rer = 70 * (weight * weight * weight).toDouble();
    } else {
      rer = 70 * (weight * 0.75);
    }

    // Activity multiplier
    double multiplier = 1.6; // Average activity
    if (age < 1) multiplier = 3.0; // Growing
    else if (age > 7) multiplier = 1.2; // Senior

    return rer * multiplier;
  }

  // Calculate variance for statistical analysis
  static double _calculateVariance(List<double> values, double mean) {
    if (values.isEmpty) return 0.0;
    final squaredDiffs = values.map((v) => (v - mean) * (v - mean));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  // Generate natural language health summary (simulated LLM response)
  static String generateHealthSummary(
    Pet pet,
    List<HealthInsight> insights,
  ) {
    if (insights.isEmpty) {
      return '${pet.name} appears to be in good health based on recent data. Continue regular monitoring and maintain current care routine.';
    }

    final highPriorityInsights = insights.where((i) => i.confidence > 0.75).toList();
    final healthInsights = insights.where((i) => i.category == InsightCategory.health).toList();
    final behaviorInsights = insights.where((i) => i.category == InsightCategory.behavior).toList();

    final summary = StringBuffer();
    summary.writeln('Health Summary for ${pet.name}:');
    summary.writeln();

    if (healthInsights.isNotEmpty) {
      summary.writeln('Health Indicators:');
      for (final insight in healthInsights.take(3)) {
        summary.writeln('• ${insight.title}: ${insight.description}');
      }
      summary.writeln();
    }

    if (behaviorInsights.isNotEmpty) {
      summary.writeln('Behavioral Patterns:');
      for (final insight in behaviorInsights.take(2)) {
        summary.writeln('• ${insight.title}: ${insight.description}');
      }
      summary.writeln();
    }

    if (highPriorityInsights.isNotEmpty) {
      summary.writeln('Priority Recommendations:');
      for (final insight in highPriorityInsights.take(3)) {
        for (final rec in insight.recommendations.take(2)) {
          summary.writeln('• $rec');
        }
      }
    }

    summary.writeln();
    summary.writeln('Overall, ${highPriorityInsights.length > 2 ? "several areas need attention" : "health appears stable with minor recommendations"}. Consult a veterinarian for personalized advice.');

    return summary.toString();
  }
}
