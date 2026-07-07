import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String _currentTrack = '';

  final List<Map<String, String>> _audioTracks = [
    {'title': 'pet_bg_music_1'.tr(), 'path': 'audio/music1.mp3'},
    {'title': 'pet_bg_music_2'.tr(), 'path': 'audio/music2.mp3'},
    {'title': 'pet_bg_music_3'.tr(), 'path': 'audio/music3.mp3'},
    {'title': 'pet_bg_music_4'.tr(), 'path': 'audio/music4.mp3'},
    {'title': 'pet_bg_music_5'.tr(), 'path': 'audio/music5.mp3'},
    {'title': 'pet_bg_music_6'.tr(), 'path': 'audio/music6.mp3'},
    {'title': 'pet_bg_music_7'.tr(), 'path': 'audio/music7.mp3'},
    {'title': 'pet_bg_music_8'.tr(), 'path': 'audio/music8.mp3'},
  ];

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() => _position = position);
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => _isPlaying = false);
    });
  }

  Future<void> _playAudio(String path) async {
    try {
      await _audioPlayer.play(AssetSource(path));
      setState(() => _currentTrack = path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  Future<void> _pauseAudio() async {
    await _audioPlayer.pause();
  }

  Future<void> _resumeAudio() async {
    await _audioPlayer.resume();
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _currentTrack = '';
      _position = Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('audio_player'.tr()),
        backgroundColor: AppColors.primaryTeal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current playing info
            if (_currentTrack.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      size: 48,
                      color: AppColors.primaryTeal,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _audioTracks.firstWhere(
                        (track) => track['path'] == _currentTrack,
                        orElse: () => {'title': 'Unknown'},
                      )['title']!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slateDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    Slider(
                      value: _position.inSeconds.toDouble(),
                      max: _duration.inSeconds.toDouble(),
                      onChanged: (value) async {
                        await _audioPlayer.seek(Duration(seconds: value.toInt()));
                      },
                      activeColor: AppColors.primaryTeal,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(color: AppColors.textGrey),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(color: AppColors.textGrey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Playback controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _isPlaying ? _pauseAudio : _resumeAudio,
                          icon: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 48,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          onPressed: _stopAudio,
                          icon: const Icon(
                            Icons.stop_rounded,
                            size: 48,
                            color: AppColors.alertRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            // Audio tracks list
            Text(
              'available_tracks'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.slateDark,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _audioTracks.length,
                itemBuilder: (context, index) {
                  final track = _audioTracks[index];
                  final isCurrentTrack = track['path'] == _currentTrack;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        Icons.music_note_rounded,
                        color: isCurrentTrack
                            ? AppColors.primaryTeal
                            : AppColors.textGrey,
                      ),
                      title: Text(
                        track['title']!,
                        style: TextStyle(
                          fontWeight: isCurrentTrack
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isCurrentTrack
                              ? AppColors.primaryTeal
                              : AppColors.slateDark,
                        ),
                      ),
                      trailing: isCurrentTrack && _isPlaying
                          ? Icon(
                              Icons.pause_rounded,
                              color: AppColors.primaryTeal,
                            )
                          : Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.primaryTeal,
                            ),
                      onTap: () {
                        if (isCurrentTrack && _isPlaying) {
          _pauseAudio();
        } else if (isCurrentTrack && !_isPlaying) {
          _resumeAudio();
        } else {
          _playAudio(track['path']!);
        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
