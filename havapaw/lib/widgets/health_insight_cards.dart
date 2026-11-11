// Health screen cards: collar off, "why this status?", activity goal and walk weather
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/activity_goal.dart';
import '../models/alert_explanation.dart';
import '../models/collar_data.dart';
import '../models/daily_summary.dart';
import '../models/heat_risk.dart';
import '../models/pet.dart';
import '../services/baseline_calibration_service.dart';
import '../services/daily_summary_service.dart';
import '../services/health_intelligence_service.dart';
import '../services/ml_health_classifier_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';

BoxDecoration _card() => BoxDecoration(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    );

const _titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slateDark);

class OffBodyBanner extends StatelessWidget {
  final String petName;
  final double temperature;

  const OffBodyBanner({super.key, required this.petName, required this.temperature});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.do_not_touch_rounded, color: AppColors.amber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('collar_off_title'.tr(namedArgs: {'pet': petName}),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
                const SizedBox(height: 4),
                Text('collar_off_body'.tr(namedArgs: {'temp': temperature.toStringAsFixed(1)}),
                    style: const TextStyle(fontSize: 13, color: AppColors.slateDark, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WhyStatusCard extends StatelessWidget {
  final CollarData reading;
  final Pet pet;
  final List<DailySummary> summaries;

  const WhyStatusCard({super.key, required this.reading, required this.pet, required this.summaries});

  @override
  Widget build(BuildContext context) {
    final baseline = BaselineCalibrationService.calibrateFromSummaries(pet, summaries);
    final factors = AlertExplanation.build(
      reading,
      pet,
      hrBaseline: baseline.usedFallback ? null : baseline.hrBaseline,
      activityRatio: HealthIntelligenceService.activityRatioFromSummaries(summaries),
    );
    final flagged = AlertExplanation.flagged(factors);
    final headline = flagged.isEmpty
        ? 'why_all_normal'.tr(namedArgs: {'pet': pet.name})
        : 'why_flagged'.tr(namedArgs: {'items': flagged.map((f) => f.key.tr().toLowerCase()).join(', ')});

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _card(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Icon(Icons.lightbulb_outline_rounded,
              color: flagged.isEmpty ? AppColors.primaryTeal : AppColors.alertRed),
          title: Text('why_title'.tr(), style: _titleStyle),
          subtitle: Text(headline, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
          children: [
            for (final f in factors) _FactorRow(factor: f),
            FutureBuilder<MLClassificationResult?>(
              future: MLHealthClassifierService.classify(reading, pet, const [], summaries: summaries),
              builder: (context, snap) {
                final r = snap.data;
                if (r == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.memory_rounded, size: 16, color: AppColors.primaryTeal),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'why_ml'.tr(namedArgs: {
                            'state': 'state_${r.state.name}'.tr(),
                            'confidence': '${(r.confidence * 100).round()}%',
                          }),
                          style: const TextStyle(fontSize: 12.5, color: AppColors.slateDark),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (baseline.usedFallback)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('why_learning'.tr(namedArgs: {'pet': pet.name}),
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
              ),
          ],
        ),
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  final ExplanationFactor factor;

  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (factor.status) {
      FactorStatus.high => (AppColors.alertRed, Icons.arrow_upward_rounded),
      FactorStatus.low => (AppColors.amber, Icons.arrow_downward_rounded),
      FactorStatus.normal => (AppColors.primaryTeal, Icons.check_rounded),
      FactorStatus.info => (AppColors.textGrey, Icons.info_outline_rounded),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(factor.key.tr(), style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
          ),
          Text(factor.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(factor.reference.tr(namedArgs: factor.args),
                style: const TextStyle(fontSize: 12, color: AppColors.slateDark)),
          ),
        ],
      ),
    );
  }
}

class ActivityGoalCard extends StatelessWidget {
  final Pet pet;

  const ActivityGoalCard({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DailySummary>>(
      stream: DailySummaryService.streamForPet(pet.id ?? '', days: 30),
      builder: (context, snap) {
        final summaries = snap.data ?? const <DailySummary>[];
        final goal = ActivityGoal.goalMinutes(pet);
        final today = ActivityGoal.todayMinutes(summaries);
        final streak = ActivityGoal.streak(summaries, goal);
        final progress = (today / goal).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: _card(),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      backgroundColor: AppColors.lightTeal,
                      color: progress >= 1 ? const Color(0xFF10B981) : AppColors.primaryTeal,
                    ),
                    Text('${(progress * 100).round()}%',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('goal_title'.tr(), style: _titleStyle),
                    const SizedBox(height: 4),
                    Text('goal_progress'.tr(namedArgs: {'done': '$today', 'goal': '$goal'}),
                        style: const TextStyle(fontSize: 13, color: AppColors.slateDark)),
                    const SizedBox(height: 4),
                    Text(
                      progress >= 1
                          ? 'goal_reached'.tr(namedArgs: {'pet': pet.name})
                          : streak > 0
                              ? 'goal_streak'.tr(namedArgs: {'days': '$streak'})
                              : 'goal_hint'.tr(),
                      style: TextStyle(
                          fontSize: 12,
                          color: progress >= 1 || streak > 0 ? AppColors.darkTeal : AppColors.textGrey,
                          fontWeight: streak > 0 ? FontWeight.w600 : FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HeatRiskCard extends StatefulWidget {
  final Pet pet;
  final double? latitude;
  final double? longitude;

  const HeatRiskCard({super.key, required this.pet, this.latitude, this.longitude});

  @override
  State<HeatRiskCard> createState() => _HeatRiskCardState();
}

class _HeatRiskCardState extends State<HeatRiskCard> {
  late Future<WeatherNow?> _weather;

  @override
  void initState() {
    super.initState();
    _weather = WeatherService.current(latitude: widget.latitude, longitude: widget.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherNow?>(
      future: _weather,
      builder: (context, snap) {
        final w = snap.data;
        if (w == null) return const SizedBox.shrink(); // no location or offline
        final risk = HeatRisk.assess(
            feelsLikeC: w.feelsLikeC, airTempC: w.airTempC, humidity: w.humidity, pet: widget.pet);
        final (color, icon) = switch (risk.level) {
          HeatLevel.low => (AppColors.primaryTeal, Icons.wb_sunny_outlined),
          HeatLevel.moderate => (AppColors.amber, Icons.wb_sunny_rounded),
          HeatLevel.high => (Colors.deepOrange, Icons.thermostat_rounded),
          HeatLevel.extreme => (AppColors.alertRed, Icons.local_fire_department_rounded),
        };
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('heat_${risk.level.name}_title'.tr(), style: _titleStyle),
                    const SizedBox(height: 2),
                    Text(
                      'heat_conditions'.tr(namedArgs: {
                        'temp': w.airTempC.round().toString(),
                        'feels': w.feelsLikeC.round().toString(),
                        'humidity': '${w.humidity}',
                      }),
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 6),
                    Text('heat_${risk.level.name}_advice'.tr(namedArgs: {'pet': widget.pet.name}),
                        style: const TextStyle(fontSize: 13, color: AppColors.slateDark, height: 1.4)),
                    if (risk.sensitivePet && risk.level != HeatLevel.low)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('heat_sensitive'.tr(namedArgs: {'pet': widget.pet.name}),
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
