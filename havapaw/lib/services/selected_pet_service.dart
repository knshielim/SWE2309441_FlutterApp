import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keeps the selected pet in sync across Home and Profile screens.
class SelectedPetService {
  static String? selectedPetId;
  static final ValueNotifier<int> notifier = ValueNotifier(0);
  static const String _keySelectedPetId = 'selected_pet_id';

  // Tells listening widgets that the selected pet changed.
  static void _notify() {
    notifier.value++;
  }

  // Loads the saved pet id when the app starts.
  static Future<void> loadSelectedPetId() async {
    final prefs = await SharedPreferences.getInstance();
    selectedPetId = prefs.getString(_keySelectedPetId);
  }

  // Saves the current pet id to device storage.
  static Future<void> _saveSelectedPetId() async {
    final prefs = await SharedPreferences.getInstance();
    if (selectedPetId != null) {
      await prefs.setString(_keySelectedPetId, selectedPetId!);
    } else {
      await prefs.remove(_keySelectedPetId);
    }
  }

  // Returns the index of the currently selected pet.
  static int activeIndex(List<String> petIds) {
    if (petIds.isEmpty) return 0;
    if (selectedPetId != null) {
      final index = petIds.indexOf(selectedPetId!);
      if (index >= 0) return index;
    }
    return 0;
  }

  // Picks the first pet if the current selection is missing.
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

  // Selects one pet by id.
  static void selectPet(String petId) {
    if (selectedPetId == petId) return;
    selectedPetId = petId;
    _saveSelectedPetId();
    _notify();
  }

  // Selects the next pet in the list.
  static void selectNext(List<String> petIds) {
    if (petIds.isEmpty) return;
    final current = activeIndex(petIds);
    selectPet(petIds[(current + 1) % petIds.length]);
  }

  // Selects the previous pet in the list.
  static void selectPrevious(List<String> petIds) {
    if (petIds.isEmpty) return;
    final current = activeIndex(petIds);
    selectPet(petIds[(current - 1 + petIds.length) % petIds.length]);
  }

  // Updates the selection after a pet is deleted.
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
