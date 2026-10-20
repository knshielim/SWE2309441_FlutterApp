import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/collar_data.dart';
import '../theme/app_theme.dart';

// Shows how fresh the latest collar reading is ("Updated 2 min ago"), whether
// the collar is still sending (it uploads every 30 s), and its battery level.
class CollarStatusBar extends StatefulWidget {
  final CollarData reading;

  // No upload for this long means the collar is off, out of Wi-Fi range or
  // waiting for skin contact.
  static const Duration staleAfter = Duration(minutes: 5);

  const CollarStatusBar({super.key, required this.reading});

  static String timeAgo(DateTime time, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(time);
    if (diff.inMinutes < 1) return 'just_now'.tr();
    if (diff.inHours < 1) return 'minutes_ago'.tr(args: [diff.inMinutes.toString()]);
    if (diff.inDays < 1) return 'hours_ago'.tr(args: [diff.inHours.toString()]);
    return 'days_ago'.tr(args: [diff.inDays.toString()]);
  }

  @override
  State<CollarStatusBar> createState() => _CollarStatusBarState();
}

class _CollarStatusBarState extends State<CollarStatusBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Keep "x min ago" and the live/stale badge current without new data.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final isLive = DateTime.now().difference(reading.timestamp) <= CollarStatusBar.staleAfter;
    final battery = reading.batteryLevel;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Chip(
          icon: isLive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
          label: isLive ? 'collar_live'.tr() : 'collar_no_recent_data'.tr(),
          color: isLive ? AppColors.primaryTeal : AppColors.amber,
        ),
        Text(
          'collar_updated_ago'.tr(args: [CollarStatusBar.timeAgo(reading.timestamp)]),
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
        if (battery != null)
          _Chip(
            icon: battery < 15
                ? Icons.battery_alert_rounded
                : battery < 50
                    ? Icons.battery_3_bar_rounded
                    : Icons.battery_full_rounded,
            label: 'collar_battery_pct'.tr(args: [battery.toString()]),
            color: battery < 15 ? AppColors.alertRed : AppColors.slateDark,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
