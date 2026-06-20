import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../services/watch_data_service.dart';
import '../services/pet_service.dart';
import '../services/geofence_service.dart';
import '../models/watch_data.dart';
import '../models/pet.dart';
import '../models/geofence.dart';
import 'bluetooth_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _watchDataService = WatchDataService();
  final _petService = PetService();
  final _geofenceService = GeofenceService();
  int _activePetIndex = 0;

  void _showGeofenceForm({required String petId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GeofenceFormSheet(
        petId: petId,
        onSave: (geofence) async {
          await _geofenceService.addGeofence(geofence);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('live_map'.tr(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.slateDark)),
            Text('track_pet_location'.tr(), style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
            const SizedBox(height: 20),

            // Safe zone toggle
            StreamBuilder<List<Pet>>(
              stream: _petService.getPets(),
              builder: (context, petSnapshot) {
                final pets = petSnapshot.data ?? [];
                if (pets.isEmpty) {
                  return const SizedBox.shrink();
                }
                if (_activePetIndex >= pets.length) _activePetIndex = 0;
                final pet = pets[_activePetIndex];
                
                return StreamBuilder<List<Geofence>>(
                  stream: _geofenceService.getGeofencesForPet(pet.id ?? ''),
                  builder: (context, geofenceSnapshot) {
                    final geofences = geofenceSnapshot.data ?? [];
                    final hasActiveGeofence = geofences.isNotEmpty;
                    
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: hasActiveGeofence ? AppColors.lightTeal : AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: hasActiveGeofence ? AppColors.primaryTeal.withValues(alpha: 0.3) : AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_rounded, color: hasActiveGeofence ? AppColors.primaryTeal : AppColors.textGrey, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasActiveGeofence ? 'safe_zone_active'.tr() : 'no_safe_zone'.tr(),
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.slateDark),
                                ),
                                Text(
                                  hasActiveGeofence ? 'pet_within_zone'.tr() : 'configure_safe_zone'.tr(),
                                  style: TextStyle(fontSize: 12, color: hasActiveGeofence ? AppColors.primaryTeal : AppColors.textGrey),
                                ),
                              ],
                            ),
                          ),
                          if (hasActiveGeofence)
                            const Icon(Icons.check_circle_rounded, color: AppColors.primaryTeal, size: 22)
                          else
                            IconButton(
                              onPressed: () => _showGeofenceForm(petId: pet.id ?? ''),
                              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryTeal, size: 22),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Map placeholder
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.lightTeal,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.map_rounded, color: AppColors.primaryTeal, size: 54),
                    ),
                    const SizedBox(height: 16),
                    Text('gps_map'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'connect_collar_gps'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const BluetoothScreen()));
                      },
                      icon: const Icon(Icons.bluetooth_rounded, size: 18),
                      label: Text('connect_collar'.tr()),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(180, 46),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Location info
            StreamBuilder<WatchData?>(
              stream: _watchDataService.getLatestWatchData(),
              builder: (context, snapshot) {
                final watchData = snapshot.data;
                final batteryLevel = watchData?.batteryLevel;
                
                return Row(
                  children: [
                    Expanded(
                      child: _LocationCard(
                        icon: Icons.location_history_rounded,
                        label: 'last_known'.tr(),
                        value: 'home'.tr(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LocationCard(
                        icon: Icons.battery_charging_full_rounded,
                        label: 'collar_battery'.tr(),
                        value: batteryLevel != null ? '$batteryLevel%' : '--',
                      ),
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

class _LocationCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LocationCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryTeal, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GeofenceFormSheet extends StatefulWidget {
  final String petId;
  final Future<void> Function(Geofence) onSave;

  const _GeofenceFormSheet({
    required this.petId,
    required this.onSave,
  });

  @override
  State<_GeofenceFormSheet> createState() => _GeofenceFormSheetState();
}

class _GeofenceFormSheetState extends State<_GeofenceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _latitudeCtrl;
  late TextEditingController _longitudeCtrl;
  late TextEditingController _radiusCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: 'Home');
    _latitudeCtrl = TextEditingController(text: '3.1390'); // Default: Kuala Lumpur
    _longitudeCtrl = TextEditingController(text: '101.6869');
    _radiusCtrl = TextEditingController(text: '100');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final geofence = Geofence(
      petId: widget.petId,
      name: _nameCtrl.text.trim(),
      latitude: double.tryParse(_latitudeCtrl.text) ?? 0.0,
      longitude: double.tryParse(_longitudeCtrl.text) ?? 0.0,
      radius: double.tryParse(_radiusCtrl.text) ?? 100.0,
      isActive: true,
      createdAt: DateTime.now(),
    );
    
    await widget.onSave(geofence);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
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
                'configure_safe_zone'.tr(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.slateDark),
              ),
              const SizedBox(height: 8),
              Text(
                'safe_zone_desc'.tr(),
                style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'zone_name'.tr(),
                  hintText: 'zone_name_hint'.tr(),
                  prefixIcon: const Icon(Icons.location_city_rounded, color: AppColors.textGrey),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'required'.tr();
                  if (v.trim().length < 2) return 'Name must be at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _latitudeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'latitude'.tr(),
                  hintText: 'latitude_hint'.tr(),
                  prefixIcon: const Icon(Icons.place_rounded, color: AppColors.textGrey),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'required'.tr();
                  final lat = double.tryParse(v);
                  if (lat == null || lat < -90 || lat > 90) return 'Invalid latitude (-90 to 90)';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _longitudeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'longitude'.tr(),
                  hintText: 'longitude_hint'.tr(),
                  prefixIcon: const Icon(Icons.place_rounded, color: AppColors.textGrey),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'required'.tr();
                  final lng = double.tryParse(v);
                  if (lng == null || lng < -180 || lng > 180) return 'Invalid longitude (-180 to 180)';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _radiusCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'radius_meters'.tr(),
                  hintText: 'radius_hint'.tr(),
                  prefixIcon: const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.textGrey),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'required'.tr();
                  final radius = double.tryParse(v);
                  if (radius == null || radius < 10 || radius > 10000) return 'Invalid radius (10-10000 meters)';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('create_safe_zone'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
