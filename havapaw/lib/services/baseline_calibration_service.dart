// Personal heart-rate baseline
import '../models/collar_data.dart';
import '../models/daily_summary.dart';
import '../models/pet.dart';
import 'health_intelligence_service.dart';

class CalibratedBaseline {
  final double hrBaseline;

  final double hrThreshold;

  // Distinct calendar days of usable resting-state heart-rate data found.
  final int daysOfData;

  final double maturity;

  final bool usedFallback;

  CalibratedBaseline({
    required this.hrBaseline,
    required this.hrThreshold,
    required this.daysOfData,
    required this.maturity,
    required this.usedFallback,
  });
}

class BaselineCalibrationService {
  // The proposal's stated personalization window.
  static const int calibrationWindowDays = 30;

  static const double _priorPseudoDays = 30.0;

  static CalibratedBaseline calibrate(Pet pet, List<CollarData> historicalData) =>
      calibrateFromSummaries(pet, DailySummary.fromReadings(historicalData));

  static CalibratedBaseline calibrateFromSummaries(Pet pet, List<DailySummary> summaries) {
    final populationBaseline = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(pet);
    final populationThreshold = HealthIntelligenceService.getIndividualizedHeartRateThreshold(pet);

    final dailyMeans = [
      for (final s in summaries)
        if (s.restingHeartRate != null) s.restingHeartRate!,
    ];

    if (dailyMeans.isEmpty) {
      return CalibratedBaseline(
        hrBaseline: populationBaseline,
        hrThreshold: populationThreshold,
        daysOfData: 0,
        maturity: 0.0,
        usedFallback: true,
      );
    }

    final individualMean = dailyMeans.reduce((a, b) => a + b) / dailyMeans.length;
    final daysOfData = dailyMeans.length;

    final blendedBaseline =
        (daysOfData * individualMean + _priorPseudoDays * populationBaseline) /
            (daysOfData + _priorPseudoDays);

    final offset = blendedBaseline - populationBaseline;
    final blendedThreshold = (populationThreshold + offset).clamp(60.0, 220.0);

    return CalibratedBaseline(
      hrBaseline: blendedBaseline,
      hrThreshold: blendedThreshold,
      daysOfData: daysOfData,
      maturity: (daysOfData / calibrationWindowDays).clamp(0.0, 1.0),
      usedFallback: false,
    );
  }
}
