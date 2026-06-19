import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('privacy_policy'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'privacy_policy'.tr(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.slateDark),
          ),
          const SizedBox(height: 8),
          Text(
            'last_updated'.tr(),
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'information_collect'.tr(),
            content: 'information_collect_content'.tr(),
          ),
          _Section(
            title: 'use_information'.tr(),
            content: 'use_information_content'.tr(),
          ),
          _Section(
            title: 'data_security'.tr(),
            content: 'data_security_content'.tr(),
          ),
          _Section(
            title: 'data_sharing'.tr(),
            content: 'data_sharing_content'.tr(),
          ),
          _Section(
            title: 'your_rights'.tr(),
            content: 'your_rights_content'.tr(),
          ),
          _Section(
            title: 'contact_us'.tr(),
            content: 'contact_us_content'.tr(),
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
