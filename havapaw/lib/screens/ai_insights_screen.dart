import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../services/collar_data_service.dart';
import '../services/ai_health_insights_service.dart';
import '../services/pet_service.dart';
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

        setState(() {
          _insights = insights;
          _healthSummary = summary;
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
                  _AIQueryCard(pet: _pet, insights: _insights),
                ],
              ),
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

  const _AIQueryCard({required this.pet, required this.insights});

  @override
  State<_AIQueryCard> createState() => _AIQueryCardState();
}

class _AIQueryCardState extends State<_AIQueryCard> {
  final TextEditingController _queryController = TextEditingController();
  bool _isProcessing = false;
  String _response = '';

  Future<void> _submitQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isProcessing = true);

    // Simulate AI response (in production, this would call an LLM API)
    await Future.delayed(const Duration(seconds: 2));

    final response = _generateSimulatedResponse(query);

    setState(() {
      _response = response;
      _isProcessing = false;
    });
  }

  String _generateSimulatedResponse(String query) {
    final lowerQuery = query.toLowerCase();
    final petName = widget.pet?.name ?? 'your pet';

    if (lowerQuery.contains('health') || lowerQuery.contains('healthy')) {
      return 'Based on the analysis, $petName\'s health indicators show ${widget.insights.where((i) => i.category == InsightCategory.health).isEmpty ? "normal patterns" : "some areas that need attention"}. ${widget.insights.isNotEmpty ? widget.insights.first.description : ""}';
    } else if (lowerQuery.contains('exercise') || lowerQuery.contains('activity')) {
      return '$petName\'s activity levels suggest ${widget.insights.where((i) => i.category == InsightCategory.exercise).isEmpty ? "adequate exercise" : "adjustments to exercise routine"}. Consider gradual increases in activity for better health outcomes.';
    } else if (lowerQuery.contains('food') || lowerQuery.contains('eat') || lowerQuery.contains('diet')) {
      return 'Nutrition analysis indicates ${widget.insights.where((i) => i.category == InsightCategory.nutrition).isEmpty ? "balanced intake" : "potential dietary adjustments"}. Monitor calorie intake relative to activity levels for optimal weight management.';
    } else if (lowerQuery.contains('sleep') || lowerQuery.contains('rest')) {
      return 'Rest patterns analysis shows ${widget.insights.where((i) => i.category == InsightCategory.behavior).isEmpty ? "normal sleep cycles" : "variations in rest patterns"}. Adequate rest is crucial for recovery and overall health.';
    } else {
      return 'Based on the available health data for $petName, I can provide insights about health status, activity patterns, nutrition, and behavior. The AI analysis has generated ${widget.insights.length} key insights with an average confidence of ${(widget.insights.map((i) => i.confidence).reduce((a, b) => a + b) / widget.insights.length * 100).toStringAsFixed(0)}%. Would you like me to elaborate on any specific aspect?';
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
          if (_response.isNotEmpty) ...[
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
