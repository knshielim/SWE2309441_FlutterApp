import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../services/collar_data_service.dart';
import '../services/ai_health_insights_service.dart';
import '../services/pet_service.dart';
import '../services/ml_health_classifier_service.dart';
import '../services/virtual_vet_service.dart';
import '../services/baseline_calibration_service.dart';
import '../models/collar_data.dart';
import '../models/pet.dart';

class AIInsightsScreen extends StatefulWidget {
  final String petId;

  const AIInsightsScreen({super.key, required this.petId});

  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends State<AIInsightsScreen> {
  bool _isLoading = true;
  bool _hasData = false;
  List<HealthInsight> _insights = [];
  Pet? _pet;
  String _healthSummary = '';
  CollarData? _latestReading;
  List<CollarData> _historicalData = [];
  MLClassificationResult? _mlResult;
  CalibratedBaseline? _calibration;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);

    try {
      // Load pet data
      final pet = await PetService.getPetById(widget.petId);
      setState(() => _pet = pet);

      // Load collar data
      final collarDataStream = CollarDataService.getCollarDataForPet(widget.petId);
      final dataList = await collarDataStream.first;
      
      final recentData = dataList.take(50).toList();
      final historicalData = dataList.toList();

      if (pet != null && recentData.isNotEmpty) {
        // Generate AI insights
        final insights = await AIHealthInsightsService.generateHealthInsights(
          pet,
          recentData,
          historicalData,
        );

        // Generate health summary
        final summary = AIHealthInsightsService.generateHealthSummary(pet, insights);

        // Real Random Forest -> TFLite classification of the latest reading
        // (see lib/services/ml_health_classifier_service.dart)
        final mlResult = await MLHealthClassifierService.classify(
          recentData.first,
          pet,
          historicalData,
        );

        // 30-day baseline personalization status (proposal Phase 4)
        final calibration = BaselineCalibrationService.calibrate(pet, historicalData);

        setState(() {
          _insights = insights;
          _healthSummary = summary;
          _latestReading = recentData.first;
          _historicalData = historicalData;
          _mlResult = mlResult;
          _calibration = calibration;
          _hasData = true;
        });
      } else {
        setState(() {
          _hasData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading AI insights: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ai_health_insights'.tr()),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.slateDark),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryTeal, AppColors.darkTeal],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              onPressed: _loadInsights,
              tooltip: 'refresh'.tr(),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryTeal),
                  const SizedBox(height: 16),
                  Text(
                    'analyzing_data'.tr(),
                    style: TextStyle(color: AppColors.textGrey, fontSize: 14),
                  ),
                ],
              ),
            )
          : !_hasData
              ? _ConnectCollarPrompt(petName: _pet?.name ?? 'your pet')
              : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI-powered header with gradient
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryTeal, AppColors.darkTeal],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryTeal.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ai_powered_analysis'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_insights.length} ${'insights_generated'.tr()}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Real Random Forest / TFLite model prediction
                  if (_mlResult != null) ...[
                    _MLPredictionCard(
                      result: _mlResult!,
                      petName: _pet?.name ?? 'Your pet',
                      calibration: _calibration,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Health summary card
                  if (_healthSummary.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.lightTeal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.description_rounded, color: AppColors.primaryTeal, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'health_summary'.tr(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _healthSummary,
                        style: const TextStyle(fontSize: 14, color: AppColors.slateDark, height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Insights section header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.lightTeal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.lightbulb_rounded, color: AppColors.primaryTeal, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'detailed_insights'.tr(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.lightTeal,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_insights.length}',
                          style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_insights.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(60),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.lightTeal.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.insights_rounded, size: 64, color: AppColors.primaryTeal.withValues(alpha: 0.5)),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'no_insights_available'.tr(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.slateDark),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'need_more_data'.tr(),
                              style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._insights.map((insight) => _InsightCard(insight: insight)),

                  const SizedBox(height: 28),

                  // Natural language query section
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.lightTeal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.chat_rounded, color: AppColors.primaryTeal, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ask_ai'.tr(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _AIQueryCard(
                    pet: _pet,
                    insights: _insights,
                    latestReading: _latestReading,
                    historicalData: _historicalData,
                  ),
                ],
              ),
            ),
    );
  }
}

/// Displays the live Random Forest / TFLite classification result: the
/// predicted activity state and the model's confidence, with a small bar
/// chart of all four class probabilities so the reasoning is transparent
/// rather than a black-box label.
class _MLPredictionCard extends StatelessWidget {
  final MLClassificationResult result;
  final String petName;
  final CalibratedBaseline? calibration;

  const _MLPredictionCard({required this.result, required this.petName, this.calibration});

  (Color, IconData, String) _stateStyle(BuildContext context, PetActivityState state) {
    switch (state) {
      case PetActivityState.resting:
        return (AppColors.primaryTeal, Icons.bedtime_rounded, 'state_resting'.tr());
      case PetActivityState.active:
        return (const Color(0xFF10B981), Icons.directions_run_rounded, 'state_active'.tr());
      case PetActivityState.stressed:
        return (AppColors.amber, Icons.psychology_rounded, 'state_stressed'.tr());
      case PetActivityState.anomaly:
        return (AppColors.alertRed, Icons.warning_amber_rounded, 'state_anomaly'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _stateStyle(context, result.state);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ml_model_prediction'.tr(),
                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text('${(result.confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...PetActivityState.values.map((state) {
            final prob = result.allProbabilities[state] ?? 0.0;
            final (stateColor, _, stateLabel) = _stateStyle(context, state);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 74, child: Text(stateLabel, style: const TextStyle(fontSize: 12, color: AppColors.textGrey))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: prob,
                        minHeight: 8,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation(stateColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text('${(prob * 100).toStringAsFixed(0)}%',
                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                  ),
                ],
              ),
            );
          }),
          if (calibration != null) ...[
            const SizedBox(height: 4),
            Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  calibration!.maturity >= 1.0 ? Icons.verified_rounded : Icons.hourglass_bottom_rounded,
                  size: 15,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    calibration!.usedFallback
                        ? 'baseline_calibrating_new'.tr()
                        : calibration!.maturity >= 1.0
                            ? 'baseline_fully_personalized'.tr()
                            : 'baseline_calibrating_progress'.tr(namedArgs: {
                                'days': calibration!.daysOfData.toString(),
                                'total': BaselineCalibrationService.calibrationWindowDays.toString(),
                              }),
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final HealthInsight insight;

  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    Color categoryColor;
    IconData categoryIcon;
    String categoryLabel;

    switch (insight.category) {
      case InsightCategory.health:
        categoryColor = AppColors.alertRed;
        categoryIcon = Icons.favorite_rounded;
        categoryLabel = 'health'.tr();
        break;
      case InsightCategory.behavior:
        categoryColor = AppColors.amber;
        categoryIcon = Icons.psychology_rounded;
        categoryLabel = 'behavior'.tr();
        break;
      case InsightCategory.nutrition:
        categoryColor = const Color(0xFF10B981);
        categoryIcon = Icons.restaurant_rounded;
        categoryLabel = 'nutrition'.tr();
        break;
      case InsightCategory.exercise:
        categoryColor = AppColors.primaryTeal;
        categoryIcon = Icons.directions_run_rounded;
        categoryLabel = 'exercise'.tr();
        break;
      case InsightCategory.general:
        categoryColor = AppColors.slateDark;
        categoryIcon = Icons.info_rounded;
        categoryLabel = 'general'.tr();
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: categoryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with category and confidence
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slateDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              categoryLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: categoryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.lightTeal,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bar_chart_rounded, size: 12, color: AppColors.primaryTeal),
                                const SizedBox(width: 4),
                                Text(
                                  '${(insight.confidence * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primaryTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              insight.description,
              style: const TextStyle(fontSize: 14, color: AppColors.slateDark, height: 1.5),
            ),
          ),
          // Recommendations
          if (insight.recommendations.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.lightTeal.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primaryTeal),
                      const SizedBox(width: 8),
                      Text(
                        'recommendations'.tr(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...insight.recommendations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final rec = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(left: 24, top: index > 0 ? 8 : 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              rec,
                              style: const TextStyle(fontSize: 13, color: AppColors.slateDark, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AIQueryCard extends StatefulWidget {
  final Pet? pet;
  final List<HealthInsight> insights;
  final CollarData? latestReading;
  final List<CollarData> historicalData;

  const _AIQueryCard({
    required this.pet,
    required this.insights,
    required this.latestReading,
    required this.historicalData,
  });

  @override
  State<_AIQueryCard> createState() => _AIQueryCardState();
}

class _AIQueryCardState extends State<_AIQueryCard> {
  final TextEditingController _queryController = TextEditingController();
  bool _isProcessing = false;
  String _response = '';
  String? _error;

  Future<void> _submitQuery() async {
    final query = _queryController.text.trim();
    final pet = widget.pet;
    final reading = widget.latestReading;
    if (query.isEmpty || pet == null || reading == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Real GPT-4 Virtual Vet call via Firebase Cloud Function
      // (see lib/services/virtual_vet_service.dart), grounded in the
      // on-device Random Forest / TFLite classification.
      final advice = await VirtualVetService.getAdvice(
        pet: pet,
        reading: reading,
        historicalData: widget.historicalData,
        question: query,
      );
      setState(() {
        _response = advice.advice;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'virtual_vet_unavailable'.tr();
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.lightTeal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.chat_rounded, color: AppColors.primaryTeal, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ask_about_pet_health'.tr(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slateDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: 'ask_question_hint'.tr(),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: _isProcessing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryTeal),
                            )
                          : Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTeal,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            ),
                      onPressed: _isProcessing ? null : _submitQuery,
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.alertRed, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 13, color: AppColors.alertRed),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_response.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryTeal, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _response,
                      style: const TextStyle(fontSize: 14, color: AppColors.slateDark, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectCollarPrompt extends StatelessWidget {
  final String petName;

  const _ConnectCollarPrompt({required this.petName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryTeal, AppColors.darkTeal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryTeal.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bluetooth_rounded, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              'waiting_for_collar_data'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'waiting_for_collar_data_desc'.tr(namedArgs: {'petName': petName}),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_rounded, size: 20, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ai_insights_note'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
