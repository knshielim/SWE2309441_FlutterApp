import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('terms_of_service'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'terms_of_service'.tr(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.slateDark),
          ),
          const SizedBox(height: 8),
          Text(
            'last_updated'.tr(),
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'acceptance_terms'.tr(),
            content: 'acceptance_terms_content'.tr(),
          ),
          _Section(
            title: 'use_license'.tr(),
            content: 'use_license_content'.tr(),
          ),
          _Section(
            title: 'user_responsibilities'.tr(),
            content: 'user_responsibilities_content'.tr(),
          ),
          _Section(
            title: 'pet_tracking'.tr(),
            content: 'pet_tracking_content'.tr(),
          ),
          _Section(
            title: 'health_monitoring'.tr(),
            content: 'health_monitoring_content'.tr(),
          ),
          _Section(
            title: 'limitation_liability'.tr(),
            content: 'limitation_liability_content'.tr(),
          ),
          _Section(
            title: 'modifications_terms'.tr(),
            content: 'modifications_terms_content'.tr(),
          ),
          _Section(
            title: 'contact_us'.tr(),
            content: 'contact_us_tos_content'.tr(),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;

  const _Section({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slateDark),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.5),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
