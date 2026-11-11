// Health journal: weekly summary, weight chart and a timeline of alerts, check-ins and notes
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/daily_summary.dart';
import '../models/journal_entry.dart';
import '../models/weekly_summary.dart';
import '../services/alert_history_service.dart';
import '../services/daily_summary_service.dart';
import '../services/journal_service.dart';
import '../theme/app_theme.dart';

class HealthJournalScreen extends StatelessWidget {
  final String petId;
  final String petName;

  const HealthJournalScreen({super.key, required this.petId, required this.petName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('health_journal'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('journal_add'.tr()),
        onPressed: () => _showAddMenu(context),
      ),
      body: StreamBuilder<List<JournalEntry>>(
        stream: JournalService.streamForPet(petId),
        builder: (context, journalSnap) {
          return StreamBuilder<List<AlertRecord>>(
            stream: AlertHistoryService.streamAlerts(limit: 200),
            builder: (context, alertSnap) {
              return StreamBuilder<List<DailySummary>>(
                stream: DailySummaryService.streamForPet(petId, days: 14),
                builder: (context, summarySnap) {
                  if (journalSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
                  }
                  final entries = journalSnap.data ?? const <JournalEntry>[];
                  final alerts = (alertSnap.data ?? const <AlertRecord>[]).where((a) => a.petId == petId).toList();
                  final summary = WeeklySummary.build(
                    summaries: summarySnap.data ?? const [],
                    alertTimes: [for (final a in alerts) if (a.createdAt != null) a.createdAt!],
                    entries: entries,
                  );
                  final weights = entries.where((e) => e.kind == JournalEntry.kindWeight && e.weightKg != null).toList()
                    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  final timeline = _buildTimeline(entries, alerts);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      _WeeklySummaryCard(summary: summary, petName: petName),
                      if (weights.length >= 2) ...[
                        const SizedBox(height: 16),
                        _WeightChart(weights: weights),
                      ],
                      const SizedBox(height: 20),
                      Text('journal_timeline'.tr(),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
                      const SizedBox(height: 10),
                      if (timeline.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('journal_empty'.tr(),
                              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey)),
                        ),
                      ...timeline,
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Alerts and journal entries together, newest first, with a header per day
  List<Widget> _buildTimeline(List<JournalEntry> entries, List<AlertRecord> alerts) {
    final items = <_TimelineItem>[
      for (final e in entries) _TimelineItem(time: e.createdAt, entry: e),
      for (final a in alerts)
        if (a.createdAt != null) _TimelineItem(time: a.createdAt!, alert: a),
    ]..sort((a, b) => b.time.compareTo(a.time));

    final widgets = <Widget>[];
    String? lastDay;
    for (final item in items) {
      final day = DailySummary.dayKey(item.time);
      if (day != lastDay) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(DateFormat.yMMMEd().format(item.time.toLocal()),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textGrey)),
        ));
        lastDay = day;
      }
      widgets.add(_TimelineTile(item: item, petId: petId));
    }
    return widgets;
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: AppColors.primaryTeal),
              title: Text('journal_add_note'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _showNoteSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.monitor_weight_rounded, color: AppColors.primaryTeal),
              title: Text('journal_log_weight'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _showWeightDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NoteSheet(petId: petId),
    );
  }

  void _showWeightDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('journal_log_weight'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: 'kg', hintText: 'journal_weight_hint'.tr()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('cancel'.tr())),
          TextButton(
            onPressed: () async {
              final kg = double.tryParse(controller.text.replaceAll(',', '.'));
              if (kg == null || kg <= 0 || kg > 150) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('journal_weight_invalid'.tr())));
                return;
              }
              Navigator.pop(dialogContext);
              try {
                await JournalService.addWeight(petId, kg);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('journal_save_failed'.tr())));
                }
              }
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem {
  final DateTime time;
  final JournalEntry? entry;
  final AlertRecord? alert;

  _TimelineItem({required this.time, this.entry, this.alert});
}

class _TimelineTile extends StatelessWidget {
  final _TimelineItem item;
  final String petId;

  const _TimelineTile({required this.item, required this.petId});

  @override
  Widget build(BuildContext context) {
    final alert = item.alert;
    final entry = item.entry;
    late final IconData icon;
    late final Color color;
    late final String title;
    String subtitle = '';

    if (alert != null) {
      icon = Icons.notifications_active_rounded;
      color = AppColors.alertRed;
      title = alert.title;
      subtitle = alert.body;
    } else if (entry!.kind == JournalEntry.kindWeight) {
      icon = JournalEntry.iconFor(entry.kind, entry.tag);
      color = AppColors.primaryTeal;
      title = 'journal_weight_entry'.tr(namedArgs: {'kg': entry.weightKg!.toStringAsFixed(1)});
    } else if (entry.kind == JournalEntry.kindCheckIn) {
      icon = JournalEntry.iconFor(entry.kind, entry.tag);
      color = AppColors.amber;
      title = 'journal_checkin_entry'.tr(namedArgs: {'answer': 'checkin_${entry.tag}'.tr()});
      subtitle = [
        if (entry.heartRate != null) '${entry.heartRate} bpm',
        if (entry.temperature != null) '${entry.temperature!.toStringAsFixed(1)} °C',
      ].join(' · ');
    } else {
      icon = JournalEntry.iconFor(entry.kind, entry.tag);
      color = AppColors.darkTeal;
      title = 'note_${entry.tag}'.tr();
      subtitle = entry.text;
    }

    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.35)),
                ],
              ],
            ),
          ),
          Text(DateFormat.Hm().format(item.time.toLocal()),
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ],
      ),
    );

    // Owner entries can be removed by swiping; alerts stay
    if (entry == null || entry.id == null) return tile;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.alertRed, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text('journal_delete_confirm'.tr()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text('cancel'.tr())),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text('delete'.tr())),
          ],
        ),
      ),
      onDismissed: (_) => JournalService.delete(petId, entry.id!),
      child: tile,
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  final WeeklySummary summary;
  final String petName;

  const _WeeklySummaryCard({required this.summary, required this.petName});

  @override
  Widget build(BuildContext context) {
    final hrChange = summary.restingHrChange;
    final activity = summary.activityChangePct;
    String signed(double v, int digits) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(digits)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primaryTeal, AppColors.darkTeal]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('weekly_summary_title'.tr(namedArgs: {'pet': petName}),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('weekly_summary_days'.tr(namedArgs: {'days': '${summary.daysWithData}'}),
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                label: 'weekly_resting_hr'.tr(),
                value: summary.restingHr == null ? '--' : '${summary.restingHr!.toStringAsFixed(0)} bpm',
                change: hrChange == null ? null : '${signed(hrChange, 0)} bpm',
              ),
              _Stat(
                label: 'weekly_activity'.tr(),
                value: summary.avgSteps == null ? '--' : '${summary.avgSteps!.toStringAsFixed(0)} ${'steps'.tr()}',
                change: activity == null ? null : '${signed(activity, 0)}%',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'weekly_alerts'.tr(), value: '${summary.alerts}'),
              _Stat(label: 'weekly_checkins'.tr(), value: '${summary.checkIns}'),
              _Stat(label: 'weekly_notes'.tr(), value: '${summary.notes}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? change;

  const _Stat({required this.label, required this.value, this.change});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          if (change != null)
            Text('weekly_vs_last'.tr(namedArgs: {'change': change!}),
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<JournalEntry> weights;

  const _WeightChart({required this.weights});

  @override
  Widget build(BuildContext context) {
    final first = weights.first.createdAt;
    final spots = [
      for (final w in weights)
        FlSpot(w.createdAt.difference(first).inHours / 24.0, w.weightKg!),
    ];
    final values = spots.map((s) => s.y);
    final minY = values.reduce((a, b) => a < b ? a : b) - 1;
    final maxY = values.reduce((a, b) => a > b ? a : b) + 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('journal_weight_chart'.tr(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
          ),
          SizedBox(
            height: 150,
            child: LineChart(LineChartData(
              minY: minY < 0 ? 0 : minY,
              maxY: maxY,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: spots.last.x > 0 ? (spots.last.x / 3).clamp(1, double.infinity).toDouble() : 1,
                    getTitlesWidget: (x, meta) => Text(
                      DateFormat.Md().format(first.add(Duration(hours: (x * 24).round())).toLocal()),
                      style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (y, meta) =>
                        Text(y.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: AppColors.primaryTeal,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

class _NoteSheet extends StatefulWidget {
  final String petId;

  const _NoteSheet({required this.petId});

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _controller = TextEditingController();
  String _tag = JournalEntry.noteTags.first;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await JournalService.add(JournalEntry(
        petId: widget.petId,
        kind: JournalEntry.kindNote,
        tag: _tag,
        text: _controller.text.trim(),
        createdAt: DateTime.now(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('journal_save_failed'.tr())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('journal_add_note'.tr(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in JournalEntry.noteTags)
                ChoiceChip(
                  avatar: Icon(JournalEntry.iconFor(JournalEntry.kindNote, tag), size: 16),
                  label: Text('note_$tag'.tr()),
                  selected: _tag == tag,
                  selectedColor: AppColors.lightTeal,
                  onSelected: (_) => setState(() => _tag = tag),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'journal_note_hint'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('save'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
