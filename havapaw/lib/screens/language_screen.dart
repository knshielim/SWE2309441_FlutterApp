import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguageCode = 'en';

  final _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧', 'locale': const Locale('en', 'US')},
    {'code': 'id', 'name': 'Indonesian', 'flag': '🇮🇩', 'locale': const Locale('id', 'ID')},
    {'code': 'ms', 'name': 'Malay', 'flag': '🇲🇾', 'locale': const Locale('ms', 'MY')},
    {'code': 'zh', 'name': 'Chinese', 'flag': '🇨🇳', 'locale': const Locale('zh', 'CN')},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('language_code') ?? 'en';
    setState(() => _selectedLanguageCode = savedLang);
  }

  Future<void> _saveLanguage(String code, Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    if (!mounted) return;
    await context.setLocale(locale);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('language'.tr())),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('language'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'select_language'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
          ),
          const SizedBox(height: 8),
          Text(
            'choose_language'.tr(),
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 24),
          ..._languages.map((lang) => _LanguageOption(
            flag: lang['flag'] as String? ?? '',
            name: lang['name'] as String? ?? '',
            isSelected: _selectedLanguageCode == lang['code'] as String,
            onTap: () => _saveLanguage(lang['code'] as String? ?? 'en', lang['locale'] as Locale? ?? const Locale('en', 'US')),
          )),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String flag;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.flag,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.lightTeal : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primaryTeal : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Text(flag, style: const TextStyle(fontSize: 24)),
        title: Text(name, style: const TextStyle(fontSize: 14, color: AppColors.slateDark)),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryTeal, size: 24)
            : const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.textGrey, size: 24),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
