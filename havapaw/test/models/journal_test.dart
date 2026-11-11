import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:havapaw/models/collar_data.dart';
import 'package:havapaw/models/daily_summary.dart';
import 'package:havapaw/models/journal_entry.dart';
import 'package:havapaw/models/pet.dart';
import 'package:havapaw/models/spike_check.dart';
import 'package:havapaw/models/weekly_summary.dart';
import 'package:havapaw/services/health_intelligence_service.dart';

final _now = DateTime(2026, 11, 11, 15);

Pet _dog() => Pet(
      name: 'Bobby',
      type: 'dog',
      breed: 'Mixed',
      birthday: '2022-01-01',
      weight: 20,
      length: 40,
      height: 30,
      collarId: 'c1',
      ownerId: 'o1',
    );

CollarData _reading({int? hr, double? temp, Duration age = const Duration(minutes: 1)}) => CollarData(
      id: 'r1',
      deviceId: 'HavaPaw-ESP32-TEST',
      deviceName: 'collar',
      heartRate: hr,
      temperature: temp,
      timestamp: _now.subtract(age),
    );

void main() {
  group('SpikeCheck', () {
    final pet = _dog();
    final hrLimit = HealthIntelligenceService.getIndividualizedHeartRateThreshold(pet);
    final tempLimit = HealthIntelligenceService.getIndividualizedTemperatureThreshold(pet);

    test('normal reading needs no check-in', () {
      expect(SpikeCheck.reasonFor(_reading(hr: 80, temp: 38.5), pet, now: _now), isNull);
    });

    test('heart rate above the pet limit asks for context', () {
      expect(SpikeCheck.reasonFor(_reading(hr: hrLimit.toInt() + 5, temp: 38.5), pet, now: _now),
          SpikeReason.heartRate);
    });

    test('temperature above the pet limit asks for context', () {
      expect(SpikeCheck.reasonFor(_reading(hr: 80, temp: tempLimit + 0.3), pet, now: _now),
          SpikeReason.temperature);
    });

    test('35% above the personal baseline asks for context', () {
      expect(SpikeCheck.reasonFor(_reading(hr: 95, temp: 38.5), pet, hrBaseline: 70, now: _now),
          SpikeReason.heartRate);
      expect(SpikeCheck.reasonFor(_reading(hr: 90, temp: 38.5), pet, hrBaseline: 70, now: _now), isNull);
    });

    test('old readings are not asked about', () {
      expect(
          SpikeCheck.reasonFor(_reading(hr: 250, temp: 38.5, age: const Duration(hours: 2)), pet, now: _now),
          isNull);
    });

    test('advice depends on the answer', () {
      expect(SpikeCheck.adviceKeyFor('playing', SpikeReason.heartRate), 'checkin_advice_playing');
      expect(SpikeCheck.adviceKeyFor('playing', SpikeReason.temperature), 'checkin_advice_playing_temp');
      expect(SpikeCheck.adviceKeyFor('resting', SpikeReason.heartRate), 'checkin_advice_resting');
      expect(SpikeCheck.adviceKeyFor('unsure', SpikeReason.heartRate), 'checkin_advice_unsure');
    });
  });

  group('JournalEntry', () {
    test('round-trips through a Firestore map', () {
      final entry = JournalEntry(
        petId: 'p1',
        kind: JournalEntry.kindCheckIn,
        tag: 'playing',
        readingId: 'r1',
        heartRate: 160,
        temperature: 39.1,
        createdAt: _now,
      );
      final back = JournalEntry.fromMap(entry.toMap(), 'e1');
      expect(back.id, 'e1');
      expect(back.kind, JournalEntry.kindCheckIn);
      expect(back.tag, 'playing');
      expect(back.readingId, 'r1');
      expect(back.heartRate, 160);
      expect(back.temperature, 39.1);
      expect(back.createdAt, _now);
      expect(entry.toMap()['createdAt'], isA<Timestamp>());
    });

    test('check-in answers map to ML labels', () {
      expect(JournalEntry.mlLabelFor('playing'), 'active');
      expect(JournalEntry.mlLabelFor('stressed'), 'stressed');
      expect(JournalEntry.mlLabelFor('resting'), isNull);
    });
  });

  group('WeeklySummary', () {
    DailySummary day(int daysAgo, {double restHr = 70, int steps = 100}) => DailySummary(
          date: DailySummary.dayKey(_now.subtract(Duration(days: daysAgo))),
          stepsSum: steps * 10,
          stepsN: 10,
          restHrSum: restHr * 10,
          restHrN: 10,
        );

    test('compares this week with last week', () {
      final summary = WeeklySummary.build(
        summaries: [
          for (var i = 7; i < 14; i++) day(i, restHr: 70, steps: 100),
          for (var i = 0; i < 7; i++) day(i, restHr: 74, steps: 120),
        ],
        alertTimes: [_now.subtract(const Duration(days: 1)), _now.subtract(const Duration(days: 10))],
        entries: [
          JournalEntry(petId: 'p', kind: JournalEntry.kindCheckIn, tag: 'playing', createdAt: _now),
          JournalEntry(petId: 'p', kind: JournalEntry.kindNote, tag: 'vet_visit', createdAt: _now),
          JournalEntry(petId: 'p', kind: JournalEntry.kindWeight, weightKg: 20,
              createdAt: _now.subtract(const Duration(days: 9))),
        ],
        now: _now,
      );
      expect(summary.daysWithData, 7);
      expect(summary.restingHr, closeTo(74, 0.01));
      expect(summary.restingHrChange, closeTo(4, 0.01));
      expect(summary.activityChangePct, closeTo(20, 0.01));
      expect(summary.alerts, 1);
      expect(summary.checkIns, 1);
      expect(summary.notes, 1);
    });

    test('empty history gives no comparisons', () {
      final summary = WeeklySummary.build(summaries: const [], alertTimes: const [], entries: const [], now: _now);
      expect(summary.restingHr, isNull);
      expect(summary.activityChangePct, isNull);
      expect(summary.restingHrChange, isNull);
      expect(summary.alerts, 0);
    });
  });
}
