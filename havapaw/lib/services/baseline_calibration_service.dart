import '../models/collar_data.dart';
import '../models/pet.dart';
import 'health_intelligence_service.dart';

/// Result of blending a pet's population-level baseline with its own
/// accumulated collar data.
class CalibratedBaseline {
  /// Blended resting heart-rate baseline (bpm) -- population prior on day 0,
  /// shifting toward the pet's own observed resting HR as data accumulates.
  final double hrBaseline;

  /// Blended alert ceiling (bpm), shifted by the same offset as hrBaseline
  /// so the margin between "normal" and "alert" learned from the literature
  /// is preserved even as the baseline itself personalizes.
  final double hrThreshold;

  /// Distinct calendar days of usable resting-state heart-rate data found.
  final int daysOfData;

  /// 0.0 (pure population prior, day 0) to 1.0 (30+ days, mostly the pet's
  /// own data). Matches the proposal's "online learning ... first 30 days".
  final double maturity;

  /// True if there was no usable historical data at all, so hrBaseline and
  /// hrThreshold are exactly the population-formula values.
  final bool usedFallback;

  CalibratedBaseline({
    required this.hrBaseline,
    required this.hrThreshold,
    required this.daysOfData,
    required this.maturity,
    required this.usedFallback,
  });
}

/// Implements proposal Phase 4's "online learning is applied during the
/// first 30 days of usage to continuously refine the pet's baseline".
///
/// This is deliberately NOT model retraining. The TFLite classifier's
/// weights are fixed; what personalizes over time is the BASELINE fed into
/// its deviation features (see MLHealthClassifierService), using a
/// Bayesian blend of the population-level formula (breed/size/age/weight,
/// from HealthIntelligenceService -- the same one used to generate the
/// synthetic training data) and the pet's own observed resting heart rate.
///
/// Why this design, not on-device model retraining:
/// - Works identically on Android and iOS (tflite_flutter's on-device
///   training support is Android-only and experimental)
/// - Bounded and predictable: the population prior acts as a safety net,
///   so a handful of noisy early readings can't swing the baseline wildly
/// - Directly matches the proposal's actual wording ("refine the pet's
///   baseline"), which is a statistical calibration claim, not a model
///   architecture claim
/// - ALSO solves the rare-breed cold-start problem better than retraining
///   would: a pet whose true resting HR differs from the population
///   formula (e.g. an atypical individual, or a breed whose physiology
///   isn't well captured by the weight-based formula) self-corrects as its
///   own real data accumulates and increasingly outweighs the prior --
///   no breed label or retraining step required.
class BaselineCalibrationService {
  /// The proposal's stated personalization window.
  static const int calibrationWindowDays = 30;

  /// How strongly the population prior counts, in day-equivalents. Setting
  /// this equal to calibrationWindowDays means: at day 30 of real data, the
  /// individual's own history and the population prior carry equal weight;
  /// well past day 30, the pet's own data dominates.
  static const double _priorPseudoDays = 30.0;

  /// Readings with more steps than this are treated as active, not resting,
  /// and excluded from the resting-baseline calculation so a busy day
  /// doesn't drag the baseline upward.
  static const int _restingStepsCutoff = 150;

  static CalibratedBaseline calibrate(Pet pet, List<CollarData> historicalData) {
    final populationBaseline = HealthIntelligenceService.getPopulationRestingHeartRateBaseline(pet);
    final populationThreshold = HealthIntelligenceService.getIndividualizedHeartRateThreshold(pet);

    final Map<String, List<double>> dailyRestingReadings = {};
    for (final d in historicalData) {
      final hr = d.heartRate?.toDouble();
      if (hr == null) continue;
      final steps = d.steps ?? 0;
      if (steps > _restingStepsCutoff) continue;
      final key = '${d.timestamp.year}-${d.timestamp.month}-${d.timestamp.day}';
      dailyRestingReadings.putIfAbsent(key, () => []).add(hr);
    }

    if (dailyRestingReadings.isEmpty) {
      return CalibratedBaseline(
        hrBaseline: populationBaseline,
        hrThreshold: populationThreshold,
        daysOfData: 0,
        maturity: 0.0,
        usedFallback: true,
      );
    }

    final dailyMeans = dailyRestingReadings.values
        .map((readings) => readings.reduce((a, b) => a + b) / readings.length)
        .toList();
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
