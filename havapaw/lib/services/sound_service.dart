import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Plays background music and sound effects.
class SoundService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final AudioPlayer _sfxPlayer = AudioPlayer();

  static bool _isMusicEnabled = true;
  static bool _isSfxEnabled = true;
  static int _currentTrackIndex = 0;
  static double _volume = 0.5;

  static final List<String> _audioTracks = [
    'audio/music1.mp3',
    'audio/music2.mp3',
    'audio/music3.mp3',
    'audio/music4.mp3',
    'audio/music5.mp3',
    'audio/music6.mp3',
    'audio/music7.mp3',
    'audio/music8.mp3',
  ];

  // Loads saved sound settings when the app starts.
  static Future<void> init() async {
    await _loadSettings();

    _audioPlayer.onPlayerComplete.listen((_) {
      if (_isMusicEnabled) {
        _playNextTrack();
      }
    });
  }

  // Reads music and sound effect settings from device storage.
  static Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isMusicEnabled = prefs.getBool('music_enabled') ?? true;
    _isSfxEnabled = prefs.getBool('sfx_enabled') ?? true;
    _currentTrackIndex = prefs.getInt('current_track') ?? 0;
    _volume = prefs.getDouble('music_volume') ?? 0.5;
  }

  // Saves music and sound effect settings to device storage.
  static Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_enabled', _isMusicEnabled);
    await prefs.setBool('sfx_enabled', _isSfxEnabled);
    await prefs.setInt('current_track', _currentTrackIndex);
    await prefs.setDouble('music_volume', _volume);
  }

  static bool get isMusicEnabled => _isMusicEnabled;
  static bool get isSfxEnabled => _isSfxEnabled;
  static int get currentTrackIndex => _currentTrackIndex;
  static double get volume => _volume;

  // Turns background music on or off.
  static Future<void> setMusicEnabled(bool enabled) async {
    _isMusicEnabled = enabled;
    await _saveSettings();

    if (enabled) {
      await playBackgroundMusic();
    } else {
      await stopBackgroundMusic();
    }
  }

  // Turns sound effects on or off.
  static Future<void> setSfxEnabled(bool enabled) async {
    _isSfxEnabled = enabled;
    await _saveSettings();
  }

  // Sets the background music volume.
  static Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _saveSettings();
    await _audioPlayer.setVolume(_volume);
  }

  // Starts playing the current background music track.
  static Future<void> playBackgroundMusic() async {
    if (!_isMusicEnabled) return;

    try {
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(_audioTracks[_currentTrackIndex]));
    } catch (_) {
      // Audio file may be missing during development.
    }
  }

  // Plays the next track in the playlist.
  static Future<void> _playNextTrack() async {
    _currentTrackIndex = (_currentTrackIndex + 1) % _audioTracks.length;
    await _saveSettings();
    await playBackgroundMusic();
  }

  // Stops background music.
  static Future<void> stopBackgroundMusic() async {
    await _audioPlayer.stop();
  }

  // Pauses background music.
  static Future<void> pauseBackgroundMusic() async {
    await _audioPlayer.pause();
  }

  // Resumes background music if it is enabled.
  static Future<void> resumeBackgroundMusic() async {
    if (_isMusicEnabled) {
      await _audioPlayer.resume();
    }
  }

  // Skips to the next music track.
  static Future<void> playNextTrack() async {
    _currentTrackIndex = (_currentTrackIndex + 1) % _audioTracks.length;
    await _saveSettings();
    await playBackgroundMusic();
  }

  // Goes back to the previous music track.
  static Future<void> playPreviousTrack() async {
    _currentTrackIndex = (_currentTrackIndex - 1 + _audioTracks.length) % _audioTracks.length;
    await _saveSettings();
    await playBackgroundMusic();
  }

  // Selects a specific music track by index.
  static Future<void> selectTrack(int index) async {
    if (index >= 0 && index < _audioTracks.length) {
      _currentTrackIndex = index;
      await _saveSettings();
      await playBackgroundMusic();
    }
  }

  // Plays a button click sound.
  static Future<void> playClickSound() async {
    if (!_isSfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/click.mp3'));
    } catch (_) {}
  }

  // Plays a success sound.
  static Future<void> playSuccessSound() async {
    if (!_isSfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/success.mp3'));
    } catch (_) {}
  }

  // Plays an error sound.
  static Future<void> playErrorSound() async {
    if (!_isSfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/error.mp3'));
    } catch (_) {}
  }

  // Plays a notification sound.
  static Future<void> playNotificationSound() async {
    if (!_isSfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/notification.mp3'));
    } catch (_) {}
  }

  // Releases audio player resources.
  static void dispose() {
    _audioPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
