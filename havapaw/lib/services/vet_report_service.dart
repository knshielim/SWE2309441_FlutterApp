// 30-day health report as a PDF to show or send to a vet
import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart' show DateFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/activity_goal.dart';
import '../models/daily_summary.dart';
import '../models/journal_entry.dart';
import '../models/medication.dart';
import '../models/pet.dart';
import 'alert_history_service.dart';
import 'daily_summary_service.dart';
import 'health_intelligence_service.dart';
import 'journal_service.dart';
import 'medication_service.dart';

class VetReportData {
  final Pet pet;
  final List<DailySummary> summaries; // oldest first
  final List<AlertRecord> alerts; // newest first
  final List<JournalEntry> journal; // newest first
  final List<Medication> medications;
  final DateTime generatedAt;

  const VetReportData({
    required this.pet,
    required this.summaries,
    required this.alerts,
    required this.journal,
    required this.medications,
    required this.generatedAt,
  });
}

class VetReportService {
  static const int days = 30;

  // Collects the data, builds the PDF and opens the share / print sheet
  static Future<void> share(Pet pet) async {
    final data = await collect(pet);
    final bytes = await build(data, fonts: await _fonts());
    final name = pet.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    await Printing.sharePdf(bytes: bytes, filename: 'HavaPaw_${name}_report.pdf');
  }

  static Future<VetReportData> collect(Pet pet) async {
    final petId = pet.id ?? '';
    final since = DateTime.now().subtract(const Duration(days: days));
    Future<T> first<T>(Stream<T> s, T fallback) =>
        s.first.timeout(const Duration(seconds: 10), onTimeout: () => fallback);

    final results = await Future.wait([
      first(DailySummaryService.streamForPet(petId, days: days), const <DailySummary>[]),
      first(AlertHistoryService.streamAlerts(limit: 300), const <AlertRecord>[]),
      first(JournalService.streamForPet(petId), const <JournalEntry>[]),
      first<QuerySnapshot?>(MedicationService.getMedicationsForPetStream(petId), null),
    ]);
    final meds = results[3] as QuerySnapshot?;
    return VetReportData(
      pet: pet,
      summaries: results[0] as List<DailySummary>,
      alerts: (results[1] as List<AlertRecord>)
          .where((a) => a.petId == petId && a.createdAt != null && a.createdAt!.isAfter(since))
          .toList(),
      journal: (results[2] as List<JournalEntry>).where((e) => e.createdAt.isAfter(since)).toList(),
      medications: meds == null
          ? const []
          : meds.docs.map((d) => Medication.fromMap(d.data() as Map<String, dynamic>, d.id)).toList(),
      generatedAt: DateTime.now(),
    );
  }

  static Future<pw.ThemeData?> _fonts() async {
    try {
      return pw.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansRegular(),
        bold: await PdfGoogleFonts.notoSansBold(),
      );
    } catch (_) {
      return null; // offline: built-in font
    }
  }

  static Future<Uint8List> build(VetReportData d, {pw.ThemeData? fonts}) async {
    final pet = d.pet;
    final doc = pw.Document(title: '${pet.name} health report', author: 'HavaPaw', theme: fonts);
    final dateFmt = DateFormat('d MMM yyyy');
    final timeFmt = DateFormat('d MMM, HH:mm');
    final age = HealthIntelligenceService.calculatePetAge(pet.birthday);
    final goal = ActivityGoal.goalMinutes(pet);

    final restHrs = [for (final s in d.summaries) if (s.restingHeartRate != null) s.restingHeartRate!];
    final avgRestHr = restHrs.isEmpty ? null : restHrs.reduce((a, b) => a + b) / restHrs.length;
    final weights = d.journal.where((e) => e.kind == JournalEntry.kindWeight).toList();
    final notes = d.journal.where((e) => e.kind != JournalEntry.kindWeight).toList();

    pw.Widget heading(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(text, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A6F65))),
        );
    pw.Widget empty(String text) => pw.Text(text, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700));
    pw.Widget table(List<String> headers, List<List<String>> rows) => pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F9B8E)),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        );
    String tagText(String tag) => tag.replaceAll('_', ' ');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (c) => pw.Text(
        'HavaPaw collar report - sensor data and owner notes, not a diagnosis. Page ${c.pageNumber}/${c.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
      build: (c) => [
        pw.Text('${pet.name} - health report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text('Last $days days, generated ${dateFmt.format(d.generatedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        heading('Pet'),
        table(['Species', 'Breed', 'Age', 'Weight', 'Daily activity goal'], [
          [pet.type, pet.breed.isEmpty ? '-' : pet.breed, '$age years', '${pet.weight.toStringAsFixed(1)} kg', '$goal active min'],
        ]),
        heading('Summary'),
        table(['Days with collar data', 'Average resting heart rate', 'Alerts', 'Owner notes and check-ins'], [
          [
            '${d.summaries.length}',
            avgRestHr == null ? '-' : '${avgRestHr.round()} bpm',
            '${d.alerts.length}',
            '${notes.length}',
          ],
        ]),
        heading('Daily readings'),
        if (d.summaries.isEmpty)
          empty('No collar data in this period.')
        else
          table(['Date', 'Resting heart rate', 'Active minutes', 'Avg steps / 5 min'], [
            for (final s in d.summaries.reversed)
              [
                s.date,
                s.restingHeartRate == null ? '-' : '${s.restingHeartRate!.round()} bpm',
                '${s.activeMinutes}',
                s.avgStepsPerReading == null ? '-' : s.avgStepsPerReading!.round().toString(),
              ],
          ]),
        heading('Alerts'),
        if (d.alerts.isEmpty)
          empty('No alerts in this period.')
        else
          table(['When', 'Alert', 'Details'], [
            for (final a in d.alerts) [timeFmt.format(a.createdAt!.toLocal()), a.title, a.body],
          ]),
        heading('Owner notes and check-ins'),
        if (notes.isEmpty)
          empty('No notes in this period.')
        else
          table(['When', 'Type', 'Details'], [
            for (final e in notes)
              [
                timeFmt.format(e.createdAt.toLocal()),
                e.kind == JournalEntry.kindCheckIn ? 'Check-in: ${tagText(e.tag)}' : tagText(e.tag),
                [
                  if (e.heartRate != null) '${e.heartRate} bpm',
                  if (e.temperature != null) '${e.temperature!.toStringAsFixed(1)} C',
                  if (e.text.isNotEmpty) e.text,
                ].join(' - '),
              ],
          ]),
        heading('Weight'),
        if (weights.isEmpty)
          empty('No weight logged in this period.')
        else
          table(['When', 'Weight'], [
            for (final w in weights) [dateFmt.format(w.createdAt.toLocal()), '${w.weightKg!.toStringAsFixed(1)} kg'],
          ]),
        heading('Medications'),
        if (d.medications.isEmpty)
          empty('No medications recorded.')
        else
          table(['Name', 'Dosage', 'Frequency', 'Status'], [
            for (final m in d.medications) [m.name, m.dosage, m.frequency, m.isActive ? 'Active' : 'Stopped'],
          ]),
      ],
    ));
    return doc.save();
  }
}
