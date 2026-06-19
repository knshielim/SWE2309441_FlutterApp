import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'bluetooth_screen.dart';
import 'manual_watch_data_screen.dart';
import 'account_settings_screen.dart';
import 'edit_account_profile_screen.dart';
import 'language_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Account section
          _SectionHeader('account_settings'.tr()),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            label: 'pet_profile'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EditAccountProfileScreen()));
            },
          ),
          _SettingsTile(
            icon: Icons.admin_panel_settings_rounded,
            label: 'account_settings'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
            },
          ),
          const SizedBox(height: 20),

          // Preferences
          _SectionHeader('preferences'.tr()),
          _SettingsTile(
            icon: Icons.bluetooth_rounded,
            label: 'smartwatch_connection'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BluetoothScreen()));
            },
          ),
          _SettingsTile(
            icon: Icons.edit_note_rounded,
            label: 'manual_watch_data'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualWatchDataScreen()));
            },
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'notification_settings'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
            },
          ),
          _SettingsTile(
            icon: Icons.language_rounded,
            label: 'language'.tr(),
            trailing: Text(context.locale.languageCode == 'id' ? 'Indonesian' : 
                          context.locale.languageCode == 'ms' ? 'Malay' : 
                          context.locale.languageCode == 'zh' ? 'Chinese' : 'English', 
                          style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen()));
            },
          ),
          const SizedBox(height: 20),

          // About
          _SectionHeader('about'.tr()),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'app_version'.tr(),
            trailing: const Text('v1.0.0', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'privacy_policy'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
            },
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'terms_of_service'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()));
            },
          ),
          const SizedBox(height: 20),

          // Sign out
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, color: AppColors.alertRed, size: 18),
              label: Text('logout'.tr(), style: const TextStyle(color: AppColors.alertRed, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: AppColors.alertRed),
              ),
              onPressed: () async {
                await authService.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textGrey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.slateDark, size: 22),
        title: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.slateDark)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
