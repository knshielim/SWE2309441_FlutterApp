import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About HavaPaw'),
        backgroundColor: AppColors.primaryTeal,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo/Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.lightTeal,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryTeal, width: 3),
                  ),
                  child: const Icon(Icons.pets, color: AppColors.primaryTeal, size: 50),
                ),
              ),
              const SizedBox(height: 20),

              // App name and version
              const Center(
                child: Column(
                  children: [
                    Text(
                      'HavaPaw',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slateDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Description
              const Text(
                'About HavaPaw',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'HavaPaw is a smart pet tracking application designed to help you monitor your pet\'s health, activity, and location. Connect your smartwatch or manually enter data to keep track of your pet\'s wellness journey.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textGrey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Features
              const Text(
                'Key Features',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateDark,
                ),
              ),
              const SizedBox(height: 12),
              _FeatureItem(
                icon: Icons.pets,
                title: 'Pet Management',
                description: 'Add and manage multiple pets with detailed profiles',
              ),
              const SizedBox(height: 12),
              _FeatureItem(
                icon: Icons.favorite_rounded,
                title: 'Health Tracking',
                description: 'Monitor health metrics and activity levels',
              ),
              const SizedBox(height: 12),
              _FeatureItem(
                icon: Icons.bluetooth_rounded,
                title: 'Smartwatch Integration',
                description: 'Connect compatible smartwatches for automatic data sync',
              ),
              const SizedBox(height: 12),
              _FeatureItem(
                icon: Icons.location_on_rounded,
                title: 'Location Tracking',
                description: 'Track your pet\'s location with GPS collar support',
              ),
              const SizedBox(height: 24),

              // Contact
              const Text(
                'Contact Us',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateDark,
                ),
              ),
              const SizedBox(height: 12),
              _ContactItem(
                icon: Icons.email_rounded,
                label: 'Email',
                value: 'support@havapaw.com',
              ),
              const SizedBox(height: 12),
              _ContactItem(
                icon: Icons.language_rounded,
                label: 'Website',
                value: 'www.havapaw.com',
              ),
              const SizedBox(height: 30),

              // Copyright
              const Center(
                child: Text(
                  '© 2026 HavaPaw. All rights reserved.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightTeal,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryTeal, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slateDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryTeal, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.slateDark,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }
}
