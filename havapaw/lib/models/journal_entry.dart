// Health journal: owner check-ins, notes and weight logs for one pet
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class JournalEntry {
  static const kindCheckIn = 'checkin';
  static const kindNote = 'note';
  static const kindWeight = 'weight';

  // Answers to "what is your pet doing?" when a reading spikes
  static const checkInTags = ['playing', 'resting', 'stressed', 'ate', 'unsure'];

  // Quick tags for owner notes
  static const noteTags = ['vet_visit', 'vaccination', 'ate_less', 'vomited', 'new_food', 'other'];

  final String? id;
  final String petId;
  final String kind;
  final String tag;
  final String text;
  final double? weightKg;
  final String? readingId;
  final int? heartRate;
  final double? temperature;
  final DateTime createdAt;

  const JournalEntry({
    this.id,
    required this.petId,
    required this.kind,
    this.tag = '',
    this.text = '',
    this.weightKg,
    this.readingId,
    this.heartRate,
    this.temperature,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'petId': petId,
        'kind': kind,
        'tag': tag,
        'text': text,
        if (weightKg != null) 'weightKg': weightKg,
        if (readingId != null) 'readingId': readingId,
        if (heartRate != null) 'heartRate': heartRate,
        if (temperature != null) 'temperature': temperature,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory JournalEntry.fromMap(Map<String, dynamic> map, String id) {
    final created = map['createdAt'];
    return JournalEntry(
      id: id,
      petId: (map['petId'] ?? '').toString(),
      kind: (map['kind'] ?? kindNote).toString(),
      tag: (map['tag'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      readingId: map['readingId'] as String?,
      heartRate: (map['heartRate'] as num?)?.toInt(),
      temperature: (map['temperature'] as num?)?.toDouble(),
      createdAt: created is Timestamp
          ? created.toDate()
          : DateTime.tryParse(created?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  // ML label implied by a check-in answer (used by export_collar_readings.py)
  static String? mlLabelFor(String tag) {
    switch (tag) {
      case 'playing':
        return 'active';
      case 'stressed':
        return 'stressed';
      default:
        return null;
    }
  }

  static IconData iconFor(String kind, String tag) {
    if (kind == kindWeight) return Icons.monitor_weight_rounded;
    switch (tag) {
      case 'playing':
        return Icons.directions_run_rounded;
      case 'resting':
        return Icons.bedtime_rounded;
      case 'stressed':
        return Icons.psychology_rounded;
      case 'ate':
        return Icons.restaurant_rounded;
      case 'vet_visit':
        return Icons.local_hospital_rounded;
      case 'vaccination':
        return Icons.vaccines_rounded;
      case 'ate_less':
        return Icons.no_food_rounded;
      case 'vomited':
        return Icons.sick_rounded;
      case 'new_food':
        return Icons.set_meal_rounded;
      case 'unsure':
        return Icons.help_outline_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }
}
