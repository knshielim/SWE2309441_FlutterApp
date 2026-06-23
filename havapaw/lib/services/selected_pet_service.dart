import 'package:flutter/foundation.dart';

class SelectedPetService {
  static String? selectedPetId;
  static final ValueNotifier<int> notifier = ValueNotifier(0);

  static void _notify() {
    notifier.value++;
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
        _notify();
      }
      return;
    }
    if (selectedPetId == null || !petIds.contains(selectedPetId)) {
      selectedPetId = petIds.first;
      _notify();
    }
  }

  static void selectPet(String petId) {
    if (selectedPetId == petId) return;
    selectedPetId = petId;
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
        _notify();
      }
      return;
    }
    if (selectedPetId == removedPetId || !remainingPetIds.contains(selectedPetId)) {
      selectPet(remainingPetIds.first);
    }
  }
}
