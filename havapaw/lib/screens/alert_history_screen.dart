import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../services/alert_history_service.dart';
import '../widgets/collar_status_bar.dart';

// Past push alerts (saved by the server in users/{uid}/alerts), with a
// "useful / not useful" rating the owner can give each one. The ratings are
// the alert-relevance measure for the evaluation.
class AlertHistoryScreen extends StatelessWidget {
  const AlertHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('alert_history'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<AlertRecord>>(
        stream: AlertHistoryService.streamAlerts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('error_loading_data'.tr(), style: const TextStyle(color: AppColors.textGrey)),
              ),
            );
          }
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.textGrey.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'no_alerts_yet'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _AlertTile(alert: alerts[i]),
          );
        },
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertRecord alert;

  const _AlertTile({required this.alert});

  static (IconData, Color) _style(String type) {
    switch (type) {
      case 'highHeartRate':
      case 'baselineDeviation':
        return (Icons.favorite_rounded, AppColors.alertRed);
      case 'stressWarning':
        return (Icons.psychology_rounded, AppColors.amber);
      case 'highTemperature':
        return (Icons.thermostat_rounded, AppColors.amber);
      case 'geofenceExit':
        return (Icons.location_off_rounded, AppColors.alertRed);
      case 'lowBattery':
        return (Icons.battery_alert_rounded, AppColors.slateDark);
      default:
        return (Icons.notifications_rounded, AppColors.primaryTeal);
    }
  }

  static String _formatDate(BuildContext context, DateTime t) {
    final l = MaterialLocalizations.of(context);
    return '${l.formatShortMonthDay(t)}, ${l.formatTimeOfDay(TimeOfDay.fromDateTime(t))}';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style(alert.type);
    final created = alert.createdAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
                    const SizedBox(height: 4),
                    Text(alert.body, style: const TextStyle(fontSize: 13, color: AppColors.slateDark, height: 1.4)),
                    if (created != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${_formatDate(context, created)} · ${CollarStatusBar.timeAgo(created)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('was_alert_useful'.tr(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ),
              _FeedbackButton(
                alert: alert,
                value: 'useful',
                icon: Icons.thumb_up_alt_rounded,
                tooltip: 'useful'.tr(),
              ),
              const SizedBox(width: 4),
              _FeedbackButton(
                alert: alert,
                value: 'not_useful',
                icon: Icons.thumb_down_alt_rounded,
                tooltip: 'not_useful'.tr(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final AlertRecord alert;
  final String value;
  final IconData icon;
  final String tooltip;

  const _FeedbackButton({required this.alert, required this.value, required this.icon, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final selected = alert.feedback == value;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      // Tapping the selected rating again clears it.
      onPressed: () => AlertHistoryService.setFeedback(alert.id, selected ? null : value),
      icon: Icon(icon, size: 20, color: selected ? AppColors.primaryTeal : AppColors.textGrey.withValues(alpha: 0.5)),
    );
  }
}
