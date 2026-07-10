import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../services/sound_service.dart';

class MusicSelectionScreen extends StatefulWidget {
  const MusicSelectionScreen({super.key});

  @override
  State<MusicSelectionScreen> createState() => _MusicSelectionScreenState();
}

class _MusicSelectionScreenState extends State<MusicSelectionScreen> {
  int _currentTrackIndex = 0;
  bool _isPlaying = false;

  final List<String> _trackNames = [
    'pet_bg_music_1',
    'pet_bg_music_2',
    'pet_bg_music_3',
    'pet_bg_music_4',
    'pet_bg_music_5',
    'pet_bg_music_6',
    'pet_bg_music_7',
    'pet_bg_music_8',
  ];

  @override
  void initState() {
    super.initState();
    _currentTrackIndex = SoundService.currentTrackIndex;
    _isPlaying = SoundService.isMusicEnabled;
  }

  Future<void> _selectTrack(int index) async {
    setState(() {
      _currentTrackIndex = index;
    });
    await SoundService.selectTrack(index);
    setState(() {
      _isPlaying = true;
    });
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await SoundService.pauseBackgroundMusic();
      setState(() => _isPlaying = false);
    } else {
      await SoundService.resumeBackgroundMusic();
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('select_background_music'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Current playing info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.music_note_rounded : Icons.music_off_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPlaying ? 'now_playing'.tr() : 'music_paused'.tr(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _trackNames[_currentTrackIndex].tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slateDark,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.primaryTeal,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Track list
          Text(
            'available_tracks'.tr(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_trackNames.length, (index) {
            final isSelected = index == _currentTrackIndex;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryTeal.withValues(alpha: 0.1) : AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primaryTeal : AppColors.divider,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryTeal : AppColors.lightTeal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: isSelected ? Colors.white : AppColors.primaryTeal,
                    size: 20,
                  ),
                ),
                title: Text(
                  _trackNames[index].tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.slateDark,
                  ),
                ),
                trailing: isSelected
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isPlaying)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            if (_isPlaying) const SizedBox(width: 8),
                            Text(
                              _isPlaying ? 'playing'.tr() : 'selected'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
                onTap: () => _selectTrack(index),
              ),
            );
          }),
        ],
      ),
    );
  }
}
