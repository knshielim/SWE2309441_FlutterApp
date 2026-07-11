import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../services/sound_service.dart';
import 'music_selection_screen.dart';

class SoundSettingsScreen extends StatefulWidget {
  const SoundSettingsScreen({super.key});

  @override
  State<SoundSettingsScreen> createState() => _SoundSettingsScreenState();
}

class _SoundSettingsScreenState extends State<SoundSettingsScreen> {
  bool _isMusicEnabled = true;
  bool _isSfxEnabled = true;
  double _musicVolume = 0.5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isMusicEnabled = SoundService.isMusicEnabled;
      _isSfxEnabled = SoundService.isSfxEnabled;
      _musicVolume = SoundService.volume;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sound_settings'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'sound_preferences'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
          ),
          const SizedBox(height: 8),
          Text(
            'customize_audio'.tr(),
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 24),

          _SoundToggle(
            icon: Icons.music_note_rounded,
            title: 'background_music'.tr(),
            subtitle: 'play_music_in_background'.tr(),
            value: _isMusicEnabled,
            onChanged: (v) async {
              setState(() => _isMusicEnabled = v);
              await SoundService.setMusicEnabled(v);
            },
          ),
          _SettingsTile(
            icon: Icons.playlist_play_rounded,
            title: 'select_background_music'.tr(),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicSelectionScreen()));
            },
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.volume_down_rounded, color: AppColors.slateDark, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'music_volume'.tr(),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slateDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(_musicVolume * 100).toInt()}%',
                            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Slider(
                  value: _musicVolume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  activeColor: AppColors.primaryTeal,
                  onChanged: (value) async {
                    setState(() => _musicVolume = value);
                    await SoundService.setVolume(value);
                  },
                ),
              ],
            ),
          ),
          _SoundToggle(
            icon: Icons.volume_up_rounded,
            title: 'sound_effects'.tr(),
            subtitle: 'play_click_sounds'.tr(),
            value: _isSfxEnabled,
            onChanged: (v) async {
              setState(() => _isSfxEnabled = v);
              await SoundService.setSfxEnabled(v);
            },
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('sound_settings_saved'.tr())),
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

class _SoundToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _SoundToggle({
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
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
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppColors.slateDark, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey, size: 20),
          ],
        ),
      ),
    );
  }
}
