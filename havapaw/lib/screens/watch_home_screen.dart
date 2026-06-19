import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WatchHomeScreen extends StatelessWidget {
  const WatchHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Health Score - Circular Progress
              _HealthScoreCard(),
              const SizedBox(height: 12),
              
              // Activity Breakdown
              _ActivityBreakdownCard(),
              const SizedBox(height: 12),
              
              // Stats Row
              Row(
                children: [
                  Expanded(child: _WatchStatCard(icon: Icons.directions_walk, label: 'Steps', value: '7,500', unit: '/10k', color: AppColors.primaryTeal)),
                  const SizedBox(width: 8),
                  Expanded(child: _WatchStatCard(icon: Icons.straighten, label: 'Dist', value: '5.2', unit: 'km', color: AppColors.darkTeal)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _WatchStatCard(icon: Icons.local_fire_department, label: 'Cals', value: '7,500', unit: 'kcal', color: AppColors.amber)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Circular progress indicator
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryTeal),
                ),
                const Text(
                  '100',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Health Score',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Excellent',
                style: TextStyle(
                  color: AppColors.primaryTeal,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityBreakdownCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _WatchActivityRow(icon: Icons.bedtime, label: 'Sleep', value: '8.5h', color: AppColors.darkTeal),
          const SizedBox(height: 6),
          _WatchActivityRow(icon: Icons.directions_walk, label: 'Walk', value: '2.3h', color: AppColors.primaryTeal),
          const SizedBox(height: 6),
          _WatchActivityRow(icon: Icons.pause_circle, label: 'Idle', value: '13.2h', color: Colors.grey),
        ],
      ),
    );
  }
}

class _WatchActivityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _WatchActivityRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ],
    );
  }
}

class _WatchStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _WatchStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 8, color: Colors.grey),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
