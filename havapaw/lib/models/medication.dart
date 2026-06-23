import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String? id;
  final String petId;
  final String name;
  final String dosage;
  final String frequency;
  final String? notes;
  final DateTime startDate;
  final DateTime? endDate;
  final List<int> reminderTimes; // List of hour values (e.g., [8, 12, 18] for 8am, 12pm, 6pm)
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

  factory Medication.fromMap(Map<String, dynamic> map, String docId) {
    return Medication(
      id: docId,
      petId: map['petId'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      notes: map['notes'],
      startDate: map['startDate'] is String 
          ? DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String())
          : (map['startDate'] as Timestamp).toDate(),
      endDate: map['endDate'] != null 
          ? (map['endDate'] is String 
              ? DateTime.parse(map['endDate'])
              : (map['endDate'] as Timestamp).toDate())
          : null,
      reminderTimes: map['reminderTimes'] != null 
          ? List<int>.from(map['reminderTimes'])
          : (map['timeOfDay'] != null ? [int.tryParse(map['timeOfDay'].toString()) ?? 0] : []),
      isActive: map['isActive'] ?? true,
    );
  }
}
