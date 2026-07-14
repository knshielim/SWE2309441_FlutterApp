import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalkStateService {
  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(false);
  static bool _isOnWalk = false;
  static const String _walkStateKey = 'is_on_walk';

  static Future<void> loadWalkState() async {
    final prefs = await SharedPreferences.getInstance();
    _isOnWalk = prefs.getBool(_walkStateKey) ?? false;
    notifier.value = _isOnWalk;
  }

  static Future<void> setWalkState(bool isOnWalk) async {
    _isOnWalk = isOnWalk;
    notifier.value = isOnWalk;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_walkStateKey, isOnWalk);
  }

  static bool get isOnWalk => _isOnWalk;

  static Future<void> toggleWalkState() async {
    await setWalkState(!_isOnWalk);
  }
}
