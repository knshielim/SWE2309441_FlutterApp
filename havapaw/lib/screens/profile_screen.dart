import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/pet_service.dart';
import '../models/pet.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'faq_screen.dart';
 
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
 
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}
 
class _ProfileScreenState extends State<ProfileScreen> {
  final _petService = PetService();
  int _activePetIndex = 0;
 
  void _showPetForm({Pet? pet}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PetFormSheet(
        existingPet: pet,
        onSave: (newPet) async {
          if (pet == null) {
            await _petService.addPet(newPet);
          } else {
            await _petService.updatePet(pet.id, newPet.toMap());
          }
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }
 
  void _confirmDelete(String petId, String petName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('remove_pet'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text('remove_pet_confirm'.tr(namedArgs: {'petName': petName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(), style: const TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _petService.deletePet(petId);
              if (mounted) {
                Navigator.pop(context);
                setState(() => _activePetIndex = 0);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              minimumSize: const Size(80, 40),
            ),
            child: Text('remove'.tr()),
          ),
        ],
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('my_profile'.tr(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.slateDark)),
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  icon: const Icon(Icons.settings_rounded, color: AppColors.textGrey),
                ),
              ],
            ),
            const SizedBox(height: 20),
 
            // Pet section
            StreamBuilder<QuerySnapshot>(
              stream: _petService.getPetsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading pets'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No pets found yet.'));
                }

                final pets = snapshot.data!.docs
                    .map((doc) => Pet.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();

                if (_activePetIndex >= pets.length && pets.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => _activePetIndex = pets.length - 1);
                  });
                }

                return Column(
                  children: [
                    // Pet navigation header
                    if (pets.isNotEmpty) ...[
                      GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity != null) {
                            if (details.primaryVelocity! > 0) {
                              // Swipe right - go to previous
                              setState(() => _activePetIndex = (_activePetIndex - 1 + pets.length) % pets.length);
                            } else {
                              // Swipe left - go to next
                              setState(() => _activePetIndex = (_activePetIndex + 1) % pets.length);
                            }
                          }
                        },
                        child: _PetProfileCard(
                          pet: pets[_activePetIndex],
                          totalPets: pets.length,
                          currentIndex: _activePetIndex,
                          onPrev: () { setState(() => _activePetIndex = (_activePetIndex - 1 + pets.length) % pets.length); },
                          onNext: () { setState(() => _activePetIndex = (_activePetIndex + 1) % pets.length); },
                          onEdit: () => _showPetForm(pet: pets[_activePetIndex]),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Pet details table
                      _DetailsCard(pet: pets[_activePetIndex]),
                      const SizedBox(height: 14),
 
                      // Measurements
                      _MeasurementsCard(pet: pets[_activePetIndex]),
                      const SizedBox(height: 14),
 
                      // Pet settings toggles
                      const _PetSettingsCard(),
                      const SizedBox(height: 14),
 
                      // Remove pet
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.alertRed, size: 18),
                          label: Text('remove_pet'.tr(), style: const TextStyle(color: AppColors.alertRed)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: AppColors.alertRed),
                          ),
                          onPressed: () => _confirmDelete(pets[_activePetIndex].id!, pets[_activePetIndex].name),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          color: AppColors.lightTeal,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.pets, color: AppColors.primaryTeal, size: 48),
                            const SizedBox(height: 10),
                            Text('no_pets_added'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.slateDark)),
                            Text('add_first_pet_below'.tr(), style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
 
                    // Add pet button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text('add_pet'.tr()),
                        onPressed: () => _showPetForm(),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
 
            // Bottom links
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                    child: Text('about_havapaw'.tr(), style: const TextStyle(color: AppColors.slateDark, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FAQScreen())),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                    child: Text('faq'.tr(), style: const TextStyle(color: AppColors.slateDark, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
 
// ─── Pet Profile Card ──────────────────────────────────────────────────────────
class _PetProfileCard extends StatelessWidget {
  final Pet pet;
  final int totalPets;
  final int currentIndex;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onEdit;
 
  const _PetProfileCard({
    required this.pet,
    required this.totalPets,
    required this.currentIndex,
    required this.onPrev,
    required this.onNext,
    required this.onEdit,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (totalPets > 1)
                IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textGrey))
              else
                const SizedBox(width: 40),
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryTeal, width: 2.5),
                    ),
                    child: pet.imageBase64 != null && pet.imageBase64!.isNotEmpty
                        ? ClipOval(
                            child: Image.memory(
                              base64Decode(pet.imageBase64!),
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.pets, color: AppColors.primaryTeal, size: 40);
                              },
                            ),
                          )
                        : const Icon(Icons.pets, color: AppColors.primaryTeal, size: 40),
                  ),
                  const SizedBox(height: 10),
                  Text(pet.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.slateDark)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.lightTeal,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(pet.type, style: const TextStyle(color: AppColors.primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text(pet.birthday.isNotEmpty ? _calcAge(pet.birthday) : '', style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              if (totalPets > 1)
                IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey))
              else
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, color: AppColors.textGrey, size: 20)),
            ],
          ),
          if (totalPets > 1) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPets, (i) => Container(
                width: i == currentIndex ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == currentIndex ? AppColors.primaryTeal : AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onEdit,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_rounded, color: AppColors.primaryTeal, size: 14),
                  const SizedBox(width: 4),
                  Text('edit_profile'.tr(), style: const TextStyle(color: AppColors.primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
 
  String _calcAge(String birthday) {
    try {
      final dob = DateTime.parse(birthday);
      final now = DateTime.now();
      final years = now.year - dob.year;
      return years == 1 ? '1_year_old'.tr() : '${years}_years_old'.tr(namedArgs: {'years': years.toString()});
    } catch (_) {
      return '';
    }
  }
}
 
// ─── Details Card ─────────────────────────────────────────────────────────────
class _DetailsCard extends StatelessWidget {
  final Pet pet;
  const _DetailsCard({required this.pet});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _DetailRow('pet_type'.tr(), pet.type),
          _DetailRow('birthday'.tr(), pet.birthday),
          _DetailRow('collar_id'.tr(), pet.collarId.isEmpty ? '—' : pet.collarId),
          _DetailRow('breed'.tr(), pet.breed),
          _DetailRow('owner'.tr(), FirebaseAuth.instance.currentUser?.displayName ?? '—'),
        ],
      ),
    );
  }
}
 
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
 
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
          ),
        ],
      ),
    );
  }
}
 
// ─── Measurements Card ────────────────────────────────────────────────────────
class _MeasurementsCard extends StatelessWidget {
  final Pet pet;
  const _MeasurementsCard({required this.pet});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MeasureItem(icon: Icons.monitor_weight_rounded, label: 'weight'.tr(), value: '${pet.weight} kg'),
          _MeasureItem(icon: Icons.straighten_rounded, label: 'length'.tr(), value: '${pet.length} cm'),
          _MeasureItem(icon: Icons.height_rounded, label: 'height'.tr(), value: '${pet.height} cm'),
        ],
      ),
    );
  }
}
 
class _MeasureItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MeasureItem({required this.icon, required this.label, required this.value});
 
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryTeal, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
      ],
    );
  }
}
 
// ─── Pet Settings Card ────────────────────────────────────────────────────────
class _PetSettingsCard extends StatefulWidget {
  const _PetSettingsCard();
 
  @override
  State<_PetSettingsCard> createState() => _PetSettingsCardState();
}
 
class _PetSettingsCardState extends State<_PetSettingsCard> {
  bool _notifications = true;
  bool _locationAlerts = true;
  bool _healthReminders = false;
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_rounded, color: AppColors.primaryTeal, size: 18),
              const SizedBox(width: 8),
              Text('pet_settings'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
            ],
          ),
          const SizedBox(height: 12),
          _ToggleRow(
            icon: Icons.notifications_rounded,
            label: 'notifications'.tr(),
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          _ToggleRow(
            icon: Icons.location_on_rounded,
            label: 'location_alerts'.tr(),
            value: _locationAlerts,
            onChanged: (v) => setState(() => _locationAlerts = v),
          ),
          _ToggleRow(
            icon: Icons.favorite_rounded,
            label: 'health_reminders'.tr(),
            value: _healthReminders,
            onChanged: (v) => setState(() => _healthReminders = v),
          ),
        ],
      ),
    );
  }
}
 
class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Function(bool) onChanged;
 
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});
 
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textGrey, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.slateDark))),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryTeal,
            activeTrackColor: AppColors.lightTeal,
          ),
        ],
      ),
    );
  }
}
 
// ─── Pet Form Bottom Sheet ────────────────────────────────────────────────────
class _PetFormSheet extends StatefulWidget {
  final Pet? existingPet;
  final Future<void> Function(Pet) onSave;
 
  const _PetFormSheet({this.existingPet, required this.onSave});
 
  @override
  State<_PetFormSheet> createState() => _PetFormSheetState();
}
 
class _PetFormSheetState extends State<_PetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _birthdayCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _lengthCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _collarCtrl;
  String _petType = 'Dog';
  bool _isLoading = false;
  final _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _existingImageBase64;
 
  final _types = ['Dog', 'Cat'];
  
  final _dogBreeds = ['Labrador', 'Golden Retriever', 'German Shepherd', 'Bulldog', 'Poodle', 'Beagle', 'Rottweiler', 'Yorkshire Terrier', 'Boxer', 'Dachshund', 'Siberian Husky', 'Shih Tzu', 'Pomeranian', 'Chihuahua', 'Other'];
  final _catBreeds = ['Persian', 'Maine Coon', 'Siamese', 'Ragdoll', 'Bengal', 'British Shorthair', 'Sphynx', 'Scottish Fold', 'Abyssinian', 'Other'];
  
  String? _selectedBreed;
 
  @override
  void initState() {
    super.initState();
    final p = widget.existingPet;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _selectedBreed = p?.breed;
    _birthdayCtrl = TextEditingController(text: p?.birthday ?? '');
    _weightCtrl = TextEditingController(text: p?.weight.toString() ?? '');
    _lengthCtrl = TextEditingController(text: p?.length.toString() ?? '');
    _heightCtrl = TextEditingController(text: p?.height.toString() ?? '');
    _collarCtrl = TextEditingController(text: p?.collarId ?? '');
    _petType = p?.type ?? 'Dog';
    _existingImageBase64 = p?.imageBase64;
  }
 
  @override
  void dispose() {
    _nameCtrl.dispose(); _birthdayCtrl.dispose();
    _weightCtrl.dispose(); _lengthCtrl.dispose(); _heightCtrl.dispose();
    _collarCtrl.dispose();
    super.dispose();
  }
 
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final uid = FirebaseAuth.instance.currentUser!.uid;
    String? imageBase64 = _existingImageBase64;
    
    // Convert new image to Base64 if selected
    if (_selectedImage != null) {
      try {
        final bytes = await _selectedImage!.readAsBytes();
        imageBase64 = base64Encode(bytes);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'error_processing_image'.tr()}: $e')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }
    
    final pet = Pet(
      id: widget.existingPet?.id,
      name: _nameCtrl.text.trim(),
      type: _petType,
      breed: _selectedBreed ?? '',
      birthday: _birthdayCtrl.text.trim(),
      weight: double.tryParse(_weightCtrl.text) ?? 0,
      length: double.tryParse(_lengthCtrl.text) ?? 0,
      height: double.tryParse(_heightCtrl.text) ?? 0,
      collarId: _collarCtrl.text.trim(),
      ownerId: uid,
      imageBase64: imageBase64,
    );
    await widget.onSave(pet);
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error_picking_image'.tr()}: $e')),
        );
      }
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingPet != null;
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
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEdit ? 'edit_pet'.tr() : 'add_pet'.tr(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.slateDark),
              ),
              const SizedBox(height: 20),
 
              // Profile Image
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryTeal, width: 2),
                    ),
                    child: _selectedImage != null
                        ? ClipOval(
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.pets, color: AppColors.primaryTeal, size: 40);
                              },
                            ),
                          )
                        : _existingImageBase64 != null && _existingImageBase64!.isNotEmpty
                            ? ClipOval(
                                child: Image.memory(
                                  base64Decode(_existingImageBase64!),
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.pets, color: AppColors.primaryTeal, size: 40);
                                  },
                                ),
                              )
                            : const Icon(Icons.pets, color: AppColors.primaryTeal, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: Text('change_photo'.tr()),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryTeal),
                ),
              ),
              const SizedBox(height: 20),
 
              // Name
              _label('pet_name'.tr()),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(hintText: 'pet_name_hint'.tr(), prefixIcon: const Icon(Icons.pets, color: AppColors.textGrey)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'name_required'.tr();
                  if (v.trim().length < 2) return 'Name must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),
 
              // Type dropdown
              _label('pet_type'.tr()),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _petType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cardWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) {
                  setState(() {
                    _petType = v!;
                    _selectedBreed = null;
                  });
                },
              ),
              const SizedBox(height: 14),
 
              // Breed dropdown
              _label('breed'.tr()),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedBreed,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cardWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: _getBreedsForType(_petType).map((breed) => DropdownMenuItem(value: breed, child: Text(breed))).toList(),
                onChanged: (v) => setState(() => _selectedBreed = v),
                validator: (v) => v == null || v.isEmpty ? 'breed_required'.tr() : null,
              ),
              const SizedBox(height: 14),
 
              // Birthday
              _label('birthday'.tr()),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.cardWhite,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: const Icon(Icons.cake_rounded, color: AppColors.textGrey),
                    errorText: _birthdayCtrl.text.isEmpty ? 'Birthday is required' : null,
                  ),
                  child: Text(
                    _birthdayCtrl.text.isEmpty ? 'select_birthday'.tr() : _birthdayCtrl.text,
                    style: TextStyle(
                      color: _birthdayCtrl.text.isEmpty ? AppColors.textGrey : AppColors.slateDark,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
 
              // Collar ID
              _label('collar_id'.tr()),
              const SizedBox(height: 6),
              TextFormField(
                controller: _collarCtrl,
                decoration: InputDecoration(hintText: 'collar_id_hint'.tr(), prefixIcon: const Icon(Icons.nfc_rounded, color: AppColors.textGrey)),
              ),
              const SizedBox(height: 14),
 
              // Measurements row
              _label('measurements'.tr()),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: 'weight_hint'.tr()),
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          final weight = double.tryParse(v);
                          if (weight == null || weight <= 0) return 'Invalid weight';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _lengthCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: 'length_hint'.tr()),
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          final length = double.tryParse(v);
                          if (length == null || length <= 0) return 'Invalid length';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: 'height_hint'.tr()),
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          final height = double.tryParse(v);
                          if (height == null || height <= 0) return 'Invalid height';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(isEdit ? 'save_changes'.tr() : 'add_pet'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
 
  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark));

  List<String> _getBreedsForType(String type) {
    switch (type) {
      case 'Dog':
        return _dogBreeds;
      case 'Cat':
        return _catBreeds;
      default:
        return _dogBreeds;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _birthdayCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }
}