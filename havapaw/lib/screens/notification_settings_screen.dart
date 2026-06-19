import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _locationAlerts = true;
  bool _healthAlerts = true;
  bool _medicationReminders = true;
  bool _geofenceAlerts = true;
  bool _lowBatteryAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('notification_settings'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'notification_preferences'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
          ),
          const SizedBox(height: 8),
          Text(
            'choose_notifications'.tr(),
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 24),

          _NotificationToggle(
            icon: Icons.notifications_rounded,
            title: 'push_notifications'.tr(),
            subtitle: 'receive_notifications'.tr(),
            value: _pushNotifications,
            onChanged: (v) => setState(() => _pushNotifications = v),
          ),
          _NotificationToggle(
            icon: Icons.location_on_rounded,
            title: 'location_alerts'.tr(),
            subtitle: 'alert_leaves_zone'.tr(),
            value: _locationAlerts,
            onChanged: (v) => setState(() => _locationAlerts = v),
          ),
          _NotificationToggle(
            icon: Icons.favorite_rounded,
            title: 'health_alerts'.tr(),
            subtitle: 'alerts_health_metrics'.tr(),
            value: _healthAlerts,
            onChanged: (v) => setState(() => _healthAlerts = v),
          ),
          _NotificationToggle(
            icon: Icons.medication_rounded,
            title: 'medication_reminders'.tr(),
            subtitle: 'reminders_medications'.tr(),
            value: _medicationReminders,
            onChanged: (v) => setState(() => _medicationReminders = v),
          ),
          _NotificationToggle(
            icon: Icons.shield_rounded,
            title: 'geofence_alerts'.tr(),
            subtitle: 'alerts_enters_exits'.tr(),
            value: _geofenceAlerts,
            onChanged: (v) => setState(() => _geofenceAlerts = v),
          ),
          _NotificationToggle(
            icon: Icons.battery_alert_rounded,
            title: 'low_battery_alerts'.tr(),
            subtitle: 'alert_battery_low'.tr(),
            value: _lowBatteryAlerts,
            onChanged: (v) => setState(() => _lowBatteryAlerts = v),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('notification_settings_saved'.tr())),
              );
              Navigator.pop(context);
            },
            child: Text('save_settings'.tr()),
          ),
        ],
      ),
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _NotificationToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.slateDark, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryTeal,
            activeTrackColor: AppColors.lightTeal,
          ),
        ],
      ),
    );
  }
}
