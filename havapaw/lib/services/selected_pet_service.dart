import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// synchronize the pet card in home page and profile page
class SelectedPetService {
  static String? selectedPetId;
  static final ValueNotifier<int> notifier = ValueNotifier(0);
  static const String _keySelectedPetId = 'selected_pet_id';

  static void _notify() {
    notifier.value++;
  }

  static Future<void> loadSelectedPetId() async {
    final prefs = await SharedPreferences.getInstance();
    selectedPetId = prefs.getString(_keySelectedPetId);
  }

  static Future<void> _saveSelectedPetId() async {
    final prefs = await SharedPreferences.getInstance();
    if (selectedPetId != null) {
      await prefs.setString(_keySelectedPetId, selectedPetId!);
    } else {
      await prefs.remove(_keySelectedPetId);
    }
  }

  static int activeIndex(List<String> petIds) {
    if (petIds.isEmpty) return 0;
    if (selectedPetId != null) {
      final index = petIds.indexOf(selectedPetId!);
      if (index >= 0) return index;
    }
    return 0;
  }

  static void ensureValidSelection(List<String> petIds) {
    if (petIds.isEmpty) {
      if (selectedPetId != null) {
        selectedPetId = null;
        _saveSelectedPetId();
        _notify();
      }
      return;
    }
    if (selectedPetId == null || !petIds.contains(selectedPetId)) {
      selectedPetId = petIds.first;
      _saveSelectedPetId();
      _notify();
    }
  }

  static void selectPet(String petId) {
    if (selectedPetId == petId) return;
    selectedPetId = petId;
    _saveSelectedPetId();
    _notify();
  }

  static void selectNext(List<String> petIds) {
    if (petIds.isEmpty) return;
    final current = activeIndex(petIds);
    selectPet(petIds[(current + 1) % petIds.length]);
  }

  static void selectPrevious(List<String> petIds) {
    if (petIds.isEmpty) return;
    final current = activeIndex(petIds);
    selectPet(petIds[(current - 1 + petIds.length) % petIds.length]);
  }

  static void handlePetRemoved(String removedPetId, List<String> remainingPetIds) {
    if (remainingPetIds.isEmpty) {
      if (selectedPetId != null) {
        selectedPetId = null;
        _saveSelectedPetId();
        _notify();
      }
      return;
    }
    if (selectedPetId == removedPetId || !remainingPetIds.contains(selectedPetId)) {
      selectPet(remainingPetIds.first);
    }
  }
}
