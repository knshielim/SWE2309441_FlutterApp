import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<void> init() async {
    await _loadSettings();
    
    _audioPlayer.onPlayerComplete.listen((_) {
      if (_isMusicEnabled) {
        _playNextTrack();
      }
    });
  }

  static Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isMusicEnabled = prefs.getBool('music_enabled') ?? true;
    _isSfxEnabled = prefs.getBool('sfx_enabled') ?? true;
    _currentTrackIndex = prefs.getInt('current_track') ?? 0;
    _volume = prefs.getDouble('music_volume') ?? 0.5;
  }

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

  static Future<void> setMusicEnabled(bool enabled) async {
    _isMusicEnabled = enabled;
    await _saveSettings();
    
    if (enabled) {
      await playBackgroundMusic();
    } else {
      await stopBackgroundMusic();
    }
  }

  static Future<void> setSfxEnabled(bool enabled) async {
    _isSfxEnabled = enabled;
    await _saveSettings();
  }

  static Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _saveSettings();
    await _audioPlayer.setVolume(_volume);
  }

  static Future<void> playBackgroundMusic() async {
    if (!_isMusicEnabled) return;
    
    try {
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource(_audioTracks[_currentTrackIndex]));
    } catch (e) {
      print('Error playing background music: $e');
    }
  }

  static Future<void> _playNextTrack() async {
    _currentTrackIndex = (_currentTrackIndex + 1) % _audioTracks.length;
    await _saveSettings();
    await playBackgroundMusic();
  }

  static Future<void> stopBackgroundMusic() async {
    await _audioPlayer.stop();
  }

  static Future<void> pauseBackgroundMusic() async {
    await _audioPlayer.pause();
  }

  static Future<void> resumeBackgroundMusic() async {
    if (_isMusicEnabled) {
      await _audioPlayer.resume();
    }
  }

  static Future<void> playNextTrack() async {
    _currentTrackIndex = (_currentTrackIndex + 1) % _audioTracks.length;
    await _saveSettings();
    await playBackgroundMusic();
  }

  static Future<void> playPreviousTrack() async {
    _currentTrackIndex = (_currentTrackIndex - 1 + _audioTracks.length) % _audioTracks.length;
    await _saveSettings();
    await playBackgroundMusic();
  }

  static Future<void> selectTrack(int index) async {
    if (index >= 0 && index < _audioTracks.length) {
      _currentTrackIndex = index;
      await _saveSettings();
      await playBackgroundMusic();
    }
  }

  static Future<void> playClickSound() async {
    if (!_isSfxEnabled) return;
    
    try {
      await _sfxPlayer.play(AssetSource('audio/click.mp3'));
    } catch (e) {
      print('Error playing click sound: $e');
    }
  }

  static Future<void> playSuccessSound() async {
    if (!_isSfxEnabled) return;
    
    try {
      await _sfxPlayer.play(AssetSource('audio/success.mp3'));
    } catch (e) {
      print('Error playing success sound: $e');
    }
  }

  static Future<void> playErrorSound() async {
    if (!_isSfxEnabled) return;
    
    try {
      await _sfxPlayer.play(AssetSource('audio/error.mp3'));
    } catch (e) {
      print('Error playing error sound: $e');
    }
  }

  static Future<void> playNotificationSound() async {
    if (!_isSfxEnabled) return;
    
    try {
      await _sfxPlayer.play(AssetSource('audio/notification.mp3'));
    } catch (e) {
      print('Error playing notification sound: $e');
    }
  }

  static void dispose() {
    _audioPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
