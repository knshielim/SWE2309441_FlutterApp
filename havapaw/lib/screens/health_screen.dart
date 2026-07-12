import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/collar_data_service.dart';
import '../services/pet_service.dart';
import '../services/medication_service.dart';
import '../models/collar_data.dart';
import '../models/pet.dart';
import '../models/medication.dart';
import 'settings_screen.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  int _activePetIndex = 0;

  // Opens the form to add or edit a medication.
  void _showMedicationForm({Medication? medication, required String petId}) {
    if (petId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('pet_id_missing'.tr())),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MedicationFormSheet(
        existingMedication: medication,
        petId: petId,
        onSave: (newMedication) async {
          if (medication == null) {
            await MedicationService.addMedication(newMedication);
          } else {
            await MedicationService.updateMedication(medication.id ?? '', newMedication.toMap());
          }
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // Asks the user to confirm before deleting a medication.
  void _confirmDeleteMedication(String medicationId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('delete_medication'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text('delete_medication_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(), style: const TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await MedicationService.deleteMedication(medicationId);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              minimumSize: const Size(80, 40),
            ),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final fullName = user?.displayName ?? 'there';
    final firstName = fullName.split(' ')[0];
    
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user profile
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'health_monitor'.tr(),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.slateDark),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: CircleAvatar(
                    backgroundColor: AppColors.lightTeal,
                    radius: 22,
                    child: Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Header with pet name
            StreamBuilder<QuerySnapshot>(
              stream: PetService.getPetsStream(),
              builder: (context, petSnapshot) {
                if (!petSnapshot.hasData || petSnapshot.data!.docs.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('no_pets_added'.tr(), style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
                      const SizedBox(height: 20),
                      _EmptyStateCard(),
                    ],
                  );
                }
                final pets = petSnapshot.data!.docs
                    .map((doc) => Pet.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();
                if (_activePetIndex >= pets.length) _activePetIndex = 0;
                final pet = pets[_activePetIndex];
                final petId = pet.id ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${pet.name} · ${pet.type}', style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
                    const SizedBox(height: 20),
                    _HealthContent(
                      petId: petId,
                      pet: pet,
                      onShowMedicationForm: () => _showMedicationForm(petId: petId),
                      onEditMedication: (medication) => _showMedicationForm(medication: medication, petId: petId),
                      onConfirmDeleteMedication: (medicationId) => _confirmDeleteMedication(medicationId),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthContent extends StatelessWidget {
  final String petId;
  final Pet pet;
  final Function() onShowMedicationForm;
  final Function(Medication) onEditMedication;
  final Function(String) onConfirmDeleteMedication;

  const _HealthContent({
    required this.petId,
    required this.pet,
    required this.onShowMedicationForm,
    required this.onEditMedication,
    required this.onConfirmDeleteMedication,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CollarData?>(
      stream: CollarDataService.getLatestCollarData(),
      builder: (context, snapshot) {
        final collarData = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall health card
            _OverallHealthCard(collarData: collarData),
            const SizedBox(height: 16),

            // Vital signs
            Text('vital_signs'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
            const SizedBox(height: 10),
            Row(
              children: [
                _VitalCard(
                  icon: Icons.favorite_rounded,
                  label: 'heart_rate'.tr(),
                  value: collarData?.heartRate?.toString() ?? '--',
                  unit: 'bpm'.tr(),
                  color: AppColors.alertRed,
                ),
                const SizedBox(width: 12),
                _VitalCard(
                  icon: Icons.thermostat_rounded,
                  label: 'temperature'.tr(),
                  value: collarData?.temperature?.toStringAsFixed(1) ?? '--',
                  unit: 'celsius'.tr(),
                  color: AppColors.amber,
                ),
                const SizedBox(width: 12),
                _VitalCard(
                  icon: Icons.directions_run_rounded,
                  label: 'activity'.tr(),
                  value: collarData?.steps?.toString() ?? '--',
                  unit: 'steps'.tr(),
                  color: AppColors.primaryTeal,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weight card
            _InfoCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.monitor_weight_rounded, color: AppColors.primaryTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('weight'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.slateDark)),
                        Text('from_pet_profile'.tr(), style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                  Text('${pet.weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryTeal)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Medications section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('medications'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
                TextButton.icon(
                  onPressed: petId.isEmpty ? null : onShowMedicationForm,
                  icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primaryTeal),
                  label: Text('add'.tr(), style: const TextStyle(color: AppColors.primaryTeal, fontSize: 13)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (petId.isEmpty)
              _InfoCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 40, color: AppColors.amber.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'pet_id_missing'.tr(),
                          style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              StreamBuilder<QuerySnapshot>(
                stream: MedicationService.getMedicationsForPetStream(petId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: AppColors.primaryTeal),
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return _InfoCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.error_outline_rounded, size: 40, color: AppColors.alertRed.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'error_loading_medications'.tr(),
                                style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                style: const TextStyle(fontSize: 12, color: AppColors.alertRed),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _InfoCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.medication_rounded, size: 40, color: AppColors.textGrey.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'no_medications'.tr(),
                                style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  
                  final medications = snapshot.data!.docs
                      .map((doc) => Medication.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                      .toList();
                  
                  return Column(
                    children: medications.map((med) => _MedicationCard(
                      medication: med,
                      onEdit: () => onEditMedication(med),
                      onDelete: () => onConfirmDeleteMedication(med.id!),
                      onToggle: () => MedicationService.toggleMedicationStatus(med.id!, !med.isActive),
                    )).toList(),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _OverallHealthCard extends StatelessWidget {
  final CollarData? collarData;

  const _OverallHealthCard({required this.collarData});

  @override
  Widget build(BuildContext context) {
    final hasData = collarData != null;
    final isNormal = _isHealthNormal(collarData);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightTeal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isNormal ? AppColors.primaryTeal : AppColors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isNormal ? Icons.favorite_rounded : Icons.warning_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('overall_health'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.slateDark)),
                Text(
                  hasData ? (isNormal ? 'all_vitals_normal'.tr() : 'check_vitals'.tr()) : 'no_data_available'.tr(),
                  style: TextStyle(fontSize: 13, color: isNormal ? AppColors.primaryTeal : AppColors.amber),
                ),
              ],
            ),
          ),
          Icon(
            isNormal ? Icons.trending_up_rounded : Icons.trending_flat_rounded,
            color: isNormal ? AppColors.primaryTeal : AppColors.amber,
            size: 24,
          ),
        ],
      ),
    );
  }

  // Returns true when heart rate and temperature are in a normal range.
  bool _isHealthNormal(CollarData? data) {
    if (data == null) return false;
    // Simple health check logic
    if (data.heartRate != null && (data.heartRate! < 60 || data.heartRate! > 120)) return false;
    if (data.temperature != null && (data.temperature! < 36.0 || data.temperature! > 40.0)) return false;
    return true;
  }
}

class _EmptyStateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.watch_rounded, size: 48, color: AppColors.textGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'no_health_data'.tr(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slateDark),
          ),
          const SizedBox(height: 8),
          Text(
            'connect_smartwatch_health_desc'.tr(),
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _VitalCard({required this.icon, required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(unit, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _MedicationCard({
    required this.medication,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.medication_rounded, color: medication.isActive ? AppColors.primaryTeal : AppColors.textGrey, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    medication.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: medication.isActive ? AppColors.slateDark : AppColors.textGrey,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onToggle,
                    icon: Icon(
                      medication.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                      color: medication.isActive ? AppColors.primaryTeal : AppColors.textGrey,
                      size: 36,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, color: AppColors.textGrey, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_rounded, color: AppColors.alertRed, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${medication.dosage} · ${medication.frequency}', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          if (medication.notes != null && medication.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(medication.notes!, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          ],
        ],
      ),
    );
  }
}

class _MedicationFormSheet extends StatefulWidget {
  final Medication? existingMedication;
  final String petId;
  final Future<void> Function(Medication) onSave;

  const _MedicationFormSheet({
    this.existingMedication,
    required this.petId,
    required this.onSave,
  });

  @override
  State<_MedicationFormSheet> createState() => _MedicationFormSheetState();
}

class _MedicationFormSheetState extends State<_MedicationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _dosageCtrl;
  late TextEditingController _frequencyCtrl;
  late TextEditingController _notesCtrl;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  final _frequencies = ['once_daily'.tr(), 'twice_daily'.tr(), 'three_times_daily'.tr(), 'every_8_hours'.tr(), 'every_12_hours'.tr(), 'as_needed'.tr(), 'weekly'.tr()];

  @override
  void initState() {
    super.initState();
    final m = widget.existingMedication;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _dosageCtrl = TextEditingController(text: m?.dosage ?? '');
    _frequencyCtrl = TextEditingController(text: m?.frequency ?? '');
    _notesCtrl = TextEditingController(text: m?.notes ?? '');
    _startDate = m?.startDate;
    _endDate = m?.endDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _frequencyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // Saves the medication form to Firebase.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final medication = Medication(
      id: widget.existingMedication?.id,
      petId: widget.petId,
      name: _nameCtrl.text.trim(),
      dosage: _dosageCtrl.text.trim(),
      frequency: _frequencyCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      startDate: _startDate ?? DateTime.now(),
      endDate: _endDate,
      reminderTimes: [],
      isActive: widget.existingMedication?.isActive ?? true,
    );
    
    try {
      await widget.onSave(medication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error_saving_medication'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingMedication != null;
    return Container(
      padding: EdgeInsets.only(
        top: 24, left: 24, right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEdit ? 'edit_medication'.tr() : 'add_medication'.tr(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.slateDark),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'medication_name'.tr(),
                  hintText: 'medication_name_hint'.tr(),
                  prefixIcon: const Icon(Icons.medication_rounded, color: AppColors.textGrey),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'required'.tr();
                  if (v.trim().length < 2) return 'Name must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _dosageCtrl,
                decoration: InputDecoration(
                  labelText: 'dosage'.tr(),
                  hintText: 'dosage_hint'.tr(),
                  prefixIcon: const Icon(Icons.science_rounded, color: AppColors.textGrey),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'required'.tr();
                  if (v.trim().length < 2) return 'Dosage must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _frequencyCtrl.text.isEmpty ? null : _frequencyCtrl.text,
                decoration: InputDecoration(
                  labelText: 'frequency'.tr(),
                  prefixIcon: const Icon(Icons.schedule_rounded, color: AppColors.textGrey),
                ),
                items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) => setState(() => _frequencyCtrl.text = v ?? ''),
                validator: (v) => v == null || v.isEmpty ? 'required'.tr() : null,
              ),
              const SizedBox(height: 14),

              InkWell(
                onTap: () => _selectStartDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'start_date'.tr(),
                    prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.textGrey),
                    errorText: _startDate == null ? 'Start date is required' : null,
                  ),
                  child: Text(
                    _startDate != null ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}' : 'select_start_date'.tr(),
                    style: TextStyle(color: _startDate != null ? AppColors.slateDark : AppColors.textGrey),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              InkWell(
                onTap: () => _selectEndDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'end_date_optional'.tr(),
                    prefixIcon: const Icon(Icons.event_rounded, color: AppColors.textGrey),
                  ),
                  child: Text(
                    _endDate != null ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}' : 'no_end_date'.tr(),
                    style: TextStyle(color: _endDate != null ? AppColors.slateDark : AppColors.textGrey),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: 'notes_optional'.tr(),
                  hintText: 'notes_hint'.tr(),
                  prefixIcon: const Icon(Icons.note_rounded, color: AppColors.textGrey),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(isEdit ? 'save_changes'.tr() : 'add_medication'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Opens a date picker for the medication start date.
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  // Opens a date picker for the optional medication end date.
  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null && mounted) {
      setState(() => _endDate = picked);
    }
  }
}
