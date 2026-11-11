import 'package:flutter_test/flutter_test.dart';
import 'package:havapaw/models/activity_goal.dart';
import 'package:havapaw/models/alert_explanation.dart';
import 'package:havapaw/models/collar_data.dart';
import 'package:havapaw/models/collar_wear.dart';
import 'package:havapaw/models/daily_summary.dart';
import 'package:havapaw/models/heat_risk.dart';
import 'package:havapaw/models/journal_entry.dart';
import 'package:havapaw/models/medication.dart';
import 'package:havapaw/models/pet.dart';
import 'package:havapaw/models/weekly_summary.dart';
import 'package:havapaw/services/alert_history_service.dart';
import 'package:havapaw/services/vet_report_service.dart';
import 'package:havapaw/services/virtual_vet_service.dart';
import 'package:havapaw/services/weather_service.dart';

final _now = DateTime(2026, 11, 11, 15);

Pet _pet({String type = 'dog', double weight = 25, String birthday = '2022-01-01', String breed = 'Mixed'}) => Pet(
      id: 'p1',
      name: 'Bobby',
      type: type,
      breed: breed,
      birthday: birthday,
      weight: weight,
      length: 40,
      height: 30,
      collarId: 'c1',
      ownerId: 'o1',
    );

CollarData _reading({int? hr, double? temp, int? steps, double? spo2}) => CollarData(
      id: 'r1',
      deviceId: 'HavaPaw-ESP32-TEST',
      deviceName: 'collar',
      heartRate: hr,
      temperature: temp,
      steps: steps,
      bloodOxygen: spo2,
      timestamp: _now,
    );

DailySummary _day(int daysAgo, {int activeN = 0, double restHr = 70}) => DailySummary(
      date: DailySummary.dayKey(_now.subtract(Duration(days: daysAgo))),
      stepsSum: 1000,
      stepsN: 200,
      restHrSum: restHr * 100,
      restHrN: 100,
      activeN: activeN,
    );

void main() {
  group('collar off the pet', () {
    test('room temperature means the collar is off', () {
      expect(CollarWear.isOffBody(_reading(temp: 27.0)), isTrue);
      expect(CollarWear.isOffBody(_reading(temp: 38.4)), isFalse);
      expect(CollarWear.isOffBody(_reading(hr: 80)), isFalse);
    });

    test('off-body readings are left out of daily summaries', () {
      final days = DailySummary.fromReadings([
        _reading(hr: 80, temp: 38.5, steps: 300),
        CollarData(id: 'r2', deviceId: 'x', deviceName: 'x', heartRate: 60, temperature: 26, steps: 0, timestamp: _now),
      ]);
      expect(days.single.stepsN, 1);
      expect(days.single.activeN, 1);
      expect(days.single.restHrN, 0);
    });
  });

  group('why this status', () {
    test('flags heart rate far above the personal baseline', () {
      final f = AlertExplanation.build(_reading(hr: 100, temp: 38.5, steps: 20), _pet(), hrBaseline: 70);
      final hr = f.firstWhere((x) => x.key == 'why_heart_rate');
      expect(hr.status, FactorStatus.high);
      expect(hr.args['pct'], '+43%');
      expect(hr.args['baseline'], '70');
      expect(AlertExplanation.flagged(f).map((x) => x.key), ['why_heart_rate']);
    });

    test('uses the breed and age limit while the baseline is learning', () {
      final f = AlertExplanation.build(_reading(hr: 100, temp: 40.2), _pet());
      expect(f.firstWhere((x) => x.key == 'why_heart_rate').reference, 'why_vs_limit');
      expect(f.firstWhere((x) => x.key == 'why_temperature').status, FactorStatus.high);
    });

    test('low activity and low blood oxygen are flagged low', () {
      final f = AlertExplanation.build(_reading(hr: 80, temp: 38.5, spo2: 92), _pet(), activityRatio: 0.5);
      expect(AlertExplanation.flagged(f).map((x) => x.key), containsAll(['why_activity', 'why_spo2']));
      expect(AlertExplanation.flagged(f).every((x) => x.status == FactorStatus.low), isTrue);
    });
  });

  group('activity goal', () {
    test('goal by species, size and age (same as rules.js)', () {
      expect(ActivityGoal.goalMinutes(_pet(type: 'cat')), 20);
      expect(ActivityGoal.goalMinutes(_pet(weight: 8)), 40);
      expect(ActivityGoal.goalMinutes(_pet(weight: 25)), 60);
      expect(ActivityGoal.goalMinutes(_pet(weight: 60)), 45);
      expect(ActivityGoal.goalMinutes(_pet(birthday: '2014-01-01')), 30);
    });

    test('active minutes and streak', () {
      final summaries = [_day(3, activeN: 130), _day(2, activeN: 10), _day(1, activeN: 120), _day(0, activeN: 40)];
      expect(summaries.last.activeMinutes, 20);
      expect(ActivityGoal.todayMinutes(summaries, now: _now), 20);
      // today not done yet, so the streak counts back from yesterday
      expect(ActivityGoal.streak(summaries, 60, now: _now), 1);
      expect(ActivityGoal.streak([...summaries.take(3), _day(0, activeN: 125)], 60, now: _now), 2);
      expect(ActivityGoal.streak(const [], 60, now: _now), 0);
    });

    test('reads activeN from the server document', () {
      final s = DailySummary.fromMap({'stepsN': 10, 'activeN': 4, 'offBodyN': 2}, '2026-11-11');
      expect(s.activeN, 4);
      expect(s.offBodyN, 2);
      expect(s.activeMinutes, 2);
    });
  });

  group('heat risk', () {
    HeatRisk risk(double feels, {Pet? pet}) =>
        HeatRisk.assess(feelsLikeC: feels, airTempC: feels - 3, humidity: 80, pet: pet ?? _pet());

    test('levels from the feels-like temperature', () {
      expect(risk(25).level, HeatLevel.low);
      expect(risk(30).level, HeatLevel.moderate);
      expect(risk(35).level, HeatLevel.high);
      expect(risk(40).level, HeatLevel.extreme);
    });

    test('flat-faced and senior pets move up one level', () {
      expect(risk(30, pet: _pet(breed: 'French Bulldog')).level, HeatLevel.high);
      expect(risk(25, pet: _pet(birthday: '2014-01-01')).level, HeatLevel.moderate);
      expect(risk(40, pet: _pet(breed: 'Pug')).level, HeatLevel.extreme);
    });

    test('parses the Open-Meteo response', () {
      final w = WeatherNow.fromOpenMeteo({
        'current': {'temperature_2m': 31.2, 'relative_humidity_2m': 74, 'apparent_temperature': 37.9},
      }, _now);
      expect(w!.feelsLikeC, 37.9);
      expect(w.humidity, 74);
      expect(WeatherNow.fromOpenMeteo({'error': true}, _now), isNull);
    });
  });

  test('Virtual Vet context has the weekly summary and the last week of the journal', () {
    final entries = [
      JournalEntry(petId: 'p1', kind: JournalEntry.kindNote, tag: 'vomited', text: 'x' * 300, createdAt: _now),
      JournalEntry(petId: 'p1', kind: JournalEntry.kindWeight, weightKg: 24.5, createdAt: _now),
      JournalEntry(petId: 'p1', kind: JournalEntry.kindNote, tag: 'vet_visit',
          createdAt: _now.subtract(const Duration(days: 10))),
    ];
    final weekly = WeeklySummary.build(summaries: [_day(1), _day(8)], alertTimes: const [], entries: entries, now: _now);
    final ctx = VirtualVetService.buildContext(weekly, entries, now: _now);
    final journal = ctx['journal'] as List;
    expect(journal.length, 2);
    expect((journal[0] as Map)['text'].length, 200);
    expect((journal[1] as Map)['tag'], '24.5 kg');
    expect((ctx['weekly'] as Map)['restingHr'], 70.0);
  });

  test('vet report builds a PDF', () async {
    final bytes = await VetReportService.build(VetReportData(
      pet: _pet(),
      summaries: [_day(1, activeN: 100), _day(0, activeN: 50)],
      alerts: [
        AlertRecord(id: 'a', petId: 'p1', type: 'highHeartRate', title: 'High heart rate', body: '150 bpm',
            severity: 0.6, createdAt: _now),
      ],
      journal: [
        JournalEntry(petId: 'p1', kind: JournalEntry.kindCheckIn, tag: 'playing', heartRate: 150, createdAt: _now),
        JournalEntry(petId: 'p1', kind: JournalEntry.kindWeight, weightKg: 25, createdAt: _now),
      ],
      medications: [
        Medication(petId: 'p1', name: 'Heartgard', dosage: '1 tablet', frequency: 'Monthly',
            startDate: _now, reminderTimes: const []),
      ],
      generatedAt: _now,
    ));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
