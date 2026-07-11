// Represents a medication reminder for a pet.
class Medication {
  final String? id;
  final String petId;
  final String name;
  final String dosage;
  final String frequency;
  final String? notes;
  final DateTime startDate;
  final DateTime? endDate;
  final List<int> reminderTimes;
  final bool isActive;

  Medication({
    this.id,
    required this.petId,
    required this.name,
    required this.dosage,
    required this.frequency,
    this.notes,
    required this.startDate,
    this.endDate,
    required this.reminderTimes,
    this.isActive = true,
  });

  // Converts this medication to a map for Firebase storage.
  Map<String, dynamic> toMap() {
    return {
      'petId': petId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'notes': notes,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'reminderTimes': reminderTimes,
      'isActive': isActive,
    };
  }

  // Creates a Medication object from Firebase document data.
  factory Medication.fromMap(Map<String, dynamic> map, String docId) {
    return Medication(
      id: docId,
      petId: map['petId'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      notes: map['notes'],
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      reminderTimes: map['reminderTimes'] != null
          ? List<int>.from(map['reminderTimes'])
          : [],
      isActive: map['isActive'] ?? true,
    );
  }
}
