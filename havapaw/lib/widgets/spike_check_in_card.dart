// Asks the owner what the pet is doing when heart rate or temperature spikes
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/collar_data.dart';
import '../models/journal_entry.dart';
import '../models/spike_check.dart';
import '../services/journal_service.dart';
import '../theme/app_theme.dart';

class SpikeCheckInCard extends StatelessWidget {
  final CollarData reading;
  final String petId;
  final String petName;
  final SpikeReason reason;

  const SpikeCheckInCard({
    super.key,
    required this.reading,
    required this.petId,
    required this.petName,
    required this.reason,
  });

  String get _question {
    final value = reason == SpikeReason.temperature
        ? '${reading.temperature?.toStringAsFixed(1)} °C'
        : '${reading.heartRate} bpm';
    final key = reason == SpikeReason.temperature ? 'checkin_question_temp' : 'checkin_question_hr';
    return key.tr(namedArgs: {'pet': petName, 'value': value});
  }

  Future<void> _answer(BuildContext context, String tag) async {
    try {
      await JournalService.addCheckIn(JournalEntry(
        petId: petId,
        kind: JournalEntry.kindCheckIn,
        tag: tag,
        readingId: reading.id,
        heartRate: reading.heartRate,
        temperature: reading.temperature,
        createdAt: DateTime.now(),
      ));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('checkin_save_failed'.tr())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (reading.id == null) return const SizedBox.shrink();
    return StreamBuilder<JournalEntry?>(
      stream: JournalService.checkInForReading(petId, reading.id!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        final answered = snapshot.data;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.lightTeal,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
          ),
          child: answered == null ? _questionView(context) : _answeredView(answered),
        );
      },
    );
  }

  Widget _questionView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.pets_rounded, color: AppColors.primaryTeal, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_question,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in JournalEntry.checkInTags)
              ActionChip(
                avatar: Icon(JournalEntry.iconFor(JournalEntry.kindCheckIn, tag), size: 16, color: AppColors.primaryTeal),
                label: Text('checkin_$tag'.tr()),
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.divider),
                onPressed: () => _answer(context, tag),
              ),
          ],
        ),
      ],
    );
  }

  Widget _answeredView(JournalEntry answered) {
    final worrying = answered.tag == 'resting' || answered.tag == 'unsure';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(JournalEntry.iconFor(answered.kind, answered.tag),
            color: worrying ? AppColors.alertRed : AppColors.primaryTeal, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('checkin_answered'.tr(namedArgs: {'answer': 'checkin_${answered.tag}'.tr()}),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
              const SizedBox(height: 4),
              Text(SpikeCheck.adviceKeyFor(answered.tag, reason).tr(),
                  style: const TextStyle(fontSize: 13, color: AppColors.slateDark, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
