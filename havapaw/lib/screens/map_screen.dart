import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../theme/app_theme.dart';
import '../services/pet_service.dart';
import '../services/geofence_service.dart';
import '../services/pet_location_service.dart';
import '../services/selected_pet_service.dart';
import '../services/walk_state_service.dart';
import '../models/pet.dart';
import '../models/geofence.dart';
import '../utils/map_defaults.dart';
import 'settings_screen.dart';
import 'pet_location_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

// Keeps map coordinates inside valid latitude and longitude ranges.
LatLng _clampCoordinates(double lat, double lng) {
  final clampedLat = lat.clamp(-85.0, 85.0);
  final clampedLng = lng.clamp(-180.0, 180.0);
  return LatLng(clampedLat, clampedLng);
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
  }

  // Gets the user's current GPS location and centers the map.
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location services are disabled'.tr())),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Location permissions are denied'.tr())),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location permissions are permanently denied'.tr())),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        final lat = position.latitude;
        final lng = position.longitude;
        if (lat.isFinite && lng.isFinite) {
          setState(() {
            _currentPosition = position;
          });
          _mapController.move(
            _clampCoordinates(lat, lng),
            kFocusedMapZoom,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid location coordinates'.tr())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // Opens the safe zone setup form.
  void _showGeofenceForm({required String petId, List<Geofence>? geofences}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GeofenceFormSheet(
        petId: petId,
        existingGeofences: geofences,
        onSave: (geofence) async {
          if (geofence.id != null && geofence.id!.isNotEmpty) {
            await GeofenceService.updateGeofence(geofence.id!, geofence.toMap());
          } else {
            await GeofenceService.addGeofence(geofence);
          }
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final fullName = user?.displayName ?? 'there';
    final firstName = fullName.split(' ')[0];

    return SafeArea(
      child: Padding(
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
                    Text('live_map'.tr(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.slateDark)),
                    Text('track_pet_location'.tr(), style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
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

            // Safe zone toggle
            ValueListenableBuilder<int>(
              valueListenable: SelectedPetService.notifier,
              builder: (context, _, child) {
                return StreamBuilder<QuerySnapshot>(
                  stream: PetService.getPetsStream(),
                  builder: (context, petSnapshot) {
                    if (!petSnapshot.hasData || petSnapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final pets = petSnapshot.data!.docs
                        .map((doc) => Pet.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                        .toList();
                    final petIds = pets.map((pet) => pet.id!).toList();
                    SelectedPetService.ensureValidSelection(petIds);
                    final activePetIndex = SelectedPetService.activeIndex(petIds);
                    final pet = pets[activePetIndex];

                    return StreamBuilder<List<Geofence>>(
                      stream: GeofenceService.getGeofencesForPet(pet.id ?? ''),
                      builder: (context, geofenceSnapshot) {
                        final geofences = geofenceSnapshot.data ?? [];
                        final hasActiveGeofence = geofences.isNotEmpty;

                        return StreamBuilder<LatLng?>(
                          stream: pet.id != null ? PetLocationService.getPetLocation(pet.id!) : Stream.value(null),
                          builder: (context, petLocationSnapshot) {
                            final petLocation = petLocationSnapshot.data;
                            final hasPetLocation = petLocation != null &&
                                petLocation.latitude.isFinite &&
                                petLocation.longitude.isFinite;

                            // Check if pet is outside geofence
                            bool isOutside = false;
                            if (geofences.isNotEmpty && hasPetLocation) {
                              isOutside = !GeofenceService.isPetWithinGeofence(petLocation, geofences.first);
                            }

                            final isWithinSafeZone = hasActiveGeofence && !isOutside;

                            return ValueListenableBuilder<bool>(
                              valueListenable: WalkStateService.notifier,
                              builder: (context, isOnWalk, child) {
                                final showOnWalk = isOnWalk && hasActiveGeofence && isOutside;

                                return GestureDetector(
                                  onTap: () {
                                    if (hasActiveGeofence && isOutside) {
                                      WalkStateService.toggleWalkState();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: showOnWalk ? Colors.amber.withValues(alpha: 0.1) : (isWithinSafeZone ? AppColors.lightTeal : AppColors.cardWhite),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: showOnWalk ? Colors.amber : (isWithinSafeZone ? AppColors.primaryTeal.withValues(alpha: 0.3) : AppColors.divider)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          showOnWalk ? Icons.directions_walk_rounded : Icons.shield_rounded,
                                          color: showOnWalk ? Colors.amber : (isWithinSafeZone ? AppColors.primaryTeal : AppColors.textGrey),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                showOnWalk ? 'on_walk'.tr() : (isWithinSafeZone ? 'safe_zone_active'.tr() : (hasActiveGeofence ? 'pet_outside_zone'.tr() : 'no_safe_zone'.tr())),
                                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.slateDark),
                                              ),
                                              Text(
                                                showOnWalk ? 'pet_on_walk_desc'.tr() : (isWithinSafeZone ? 'pet_within_zone'.tr() : (hasActiveGeofence ? 'pet_outside_zone_desc'.tr() : 'configure_safe_zone'.tr())),
                                                style: TextStyle(fontSize: 12, color: showOnWalk ? Colors.amber : (isWithinSafeZone ? AppColors.primaryTeal : (hasActiveGeofence ? AppColors.alertRed : AppColors.textGrey))),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (hasActiveGeofence)
                                          IconButton(
                                            onPressed: () => _showGeofenceForm(petId: pet.id ?? '', geofences: geofences),
                                            icon: const Icon(Icons.edit_rounded, color: AppColors.primaryTeal, size: 22),
                                          )
                                        else
                                          IconButton(
                                            onPressed: () => _showGeofenceForm(petId: pet.id ?? ''),
                                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryTeal, size: 22),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Map
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: SelectedPetService.notifier,
                builder: (context, _, child) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: PetService.getPetsStream(),
                    builder: (context, petSnapshot) {
                      if (!petSnapshot.hasData || petSnapshot.data!.docs.isEmpty) {
                        return _buildPlaceholderMap();
                      }
                      final pets = petSnapshot.data!.docs
                          .map((doc) => Pet.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                          .toList();
                      final petIds = pets.map((pet) => pet.id!).toList();
                      SelectedPetService.ensureValidSelection(petIds);
                      final activePetIndex = SelectedPetService.activeIndex(petIds);
                      final pet = pets[activePetIndex];

                      return StreamBuilder<LatLng?>(
                        stream: pet.id != null ? PetLocationService.getPetLocation(pet.id!) : Stream.value(null),
                        builder: (context, petLocationSnapshot) {
                          final petLocation = petLocationSnapshot.data;
                          final hasUserLocation = _currentPosition != null &&
                              _currentPosition!.latitude.isFinite &&
                              _currentPosition!.longitude.isFinite;
                          final hasPetLocation = petLocation != null &&
                              petLocation.latitude.isFinite &&
                              petLocation.longitude.isFinite;

                          return Column(
                            children: [
                              Expanded(
                                child: StreamBuilder<List<Geofence>>(
                                  stream: GeofenceService.getGeofencesForPet(pet.id ?? ''),
                                  builder: (context, geofenceSnapshot) {
                                    final geofences = geofenceSnapshot.data ?? [];
                                    return _buildInteractiveMap(pet, geofences, petLocation);
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (!hasUserLocation && !hasPetLocation)
                                _MapLocationHint(
                                  onSetPetLocation: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const PetLocationScreen()),
                                    );
                                  },
                                )
                              else
                                _LocationCard(
                                  icon: Icons.location_history_rounded,
                                  label: 'last_known'.tr(),
                                  petLocation: petLocation,
                                ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shows a placeholder when no pets are added yet.
  Widget _buildPlaceholderMap() {
    return Container(
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
        ],
      ),
    );
  }

  // Builds the live map with geofence circles and location markers.
  Widget _buildInteractiveMap(Pet pet, List<Geofence> geofences, LatLng? petLocation) {
    final hasUserLocation = _currentPosition != null &&
        _currentPosition!.latitude.isFinite &&
        _currentPosition!.longitude.isFinite;
    final hasPetLocation = petLocation != null &&
        petLocation.latitude.isFinite &&
        petLocation.longitude.isFinite;

    LatLng mapCenter = kDefaultMapCenter;
    double mapZoom = kDefaultMapZoom;

    if (hasPetLocation) {
      mapCenter = petLocation;
      mapZoom = kFocusedMapZoom;
      // Move map to pet location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(petLocation, kFocusedMapZoom);
      });
    } else if (hasUserLocation) {
      mapCenter = _clampCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
      mapZoom = kFocusedMapZoom;
    } else if (geofences.isNotEmpty) {
      final geofence = geofences.first;
      if (geofence.latitude.isFinite && geofence.longitude.isFinite) {
        mapCenter = _clampCoordinates(geofence.latitude, geofence.longitude);
        mapZoom = kFocusedMapZoom;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: mapZoom,
              minZoom: 4,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.havapaw.app',
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
              ),
              // Geofence circles
              CircleLayer(
                circles: geofences.map((geofence) {
                  final lat = geofence.latitude;
                  final lng = geofence.longitude;
                  if (!lat.isFinite || !lng.isFinite) return null;
                  return CircleMarker(
                    point: _clampCoordinates(lat, lng),
                    radius: geofence.radius,
                    useRadiusInMeter: true,
                    color: AppColors.primaryTeal.withValues(alpha: 0.2),
                    borderColor: AppColors.primaryTeal,
                    borderStrokeWidth: 2,
                  );
                }).whereType<CircleMarker>().toList(),
              ),
              // Geofence center markers
              MarkerLayer(
                markers: geofences.map((geofence) {
                  final lat = geofence.latitude;
                  final lng = geofence.longitude;
                  if (!lat.isFinite || !lng.isFinite) return null;
                  return Marker(
                    point: _clampCoordinates(lat, lng),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(geofence.name)),
                        );
                      },
                      child: const Icon(
                        Icons.location_city_rounded,
                        color: AppColors.primaryTeal,
                        size: 32,
                      ),
                    ),
                  );
                }).whereType<Marker>().toList(),
              ),
              // User location marker
              if (hasUserLocation)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _clampCoordinates(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              // Pet location marker
              if (hasPetLocation)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: petLocation,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(pet.name)),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.pets_rounded,
                            color: AppColors.primaryTeal,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Floating action button to recenter
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.primaryTeal,
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLocationHint extends StatelessWidget {
  final VoidCallback onSetPetLocation;

  const _MapLocationHint({required this.onSetPetLocation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightTeal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primaryTeal, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'map_location_hint'.tr(),
                  style: const TextStyle(fontSize: 13, color: AppColors.slateDark, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onSetPetLocation,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'set_pet_location'.tr(),
              style: const TextStyle(
                color: AppColors.primaryTeal,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final LatLng? petLocation;

  const _LocationCard({required this.icon, required this.label, required this.petLocation});

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  String _address = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    if (widget.petLocation == null) {
      setState(() => _address = 'not_set'.tr());
      return;
    }

    try {
      final locations = await placemarkFromCoordinates(
        widget.petLocation!.latitude,
        widget.petLocation!.longitude,
      );
      if (locations.isNotEmpty && mounted) {
        final place = locations.first;
        final addressParts = [
          place.street,
          place.locality,
          place.administrativeArea,
        ].where((part) => part != null && part.isNotEmpty).join(', ');
        setState(() => _address = addressParts.isNotEmpty ? addressParts : 'Unknown location');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _address = 'Unknown location');
      }
    }
  }

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
          Icon(widget.icon, color: AppColors.primaryTeal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                Text(_address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slateDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GeofenceFormSheet extends StatefulWidget {
  final String petId;
  final List<Geofence>? existingGeofences;
  final Future<void> Function(Geofence) onSave;

  const _GeofenceFormSheet({
    required this.petId,
    this.existingGeofences,
    required this.onSave,
  });

  @override
  State<_GeofenceFormSheet> createState() => _GeofenceFormSheetState();
}

class _GeofenceFormSheetState extends State<_GeofenceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _radiusCtrl;
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  double _radius = 100.0;
  bool _isLoading = false;
  Geofence? _editingGeofence;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: 'Home');
    _radiusCtrl = TextEditingController(text: '100');

    // Load first existing geofence if available
    if (widget.existingGeofences != null && widget.existingGeofences!.isNotEmpty) {
      _editingGeofence = widget.existingGeofences!.first;
      _nameCtrl.text = _editingGeofence!.name;
      final geoLat = _editingGeofence!.latitude;
      final geoLng = _editingGeofence!.longitude;
      _selectedLocation = (geoLat.isFinite && geoLng.isFinite)
          ? _clampCoordinates(geoLat, geoLng)
          : null;
      _radius = _editingGeofence!.radius;
      _radiusCtrl.text = _radius.round().toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) return;
    setState(() => _isLoading = true);

    final geofence = Geofence(
      id: _editingGeofence?.id,
      petId: widget.petId,
      name: _nameCtrl.text.trim(),
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      radius: _radius,
      isActive: true,
      createdAt: _editingGeofence?.createdAt ?? DateTime.now(),
    );

    await widget.onSave(geofence);
    setState(() => _isLoading = false);
  }

  Future<void> _delete() async {
    if (_editingGeofence?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_geofence'.tr()),
        content: Text('delete_geofence_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await GeofenceService.deleteGeofence(_editingGeofence!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty && mounted) {
        final location = locations.first;
        final lat = location.latitude;
        final lng = location.longitude;
        if (lat.isFinite && lng.isFinite) {
          setState(() {
            _selectedLocation = _clampCoordinates(lat, lng);
          });
          _mapController.move(_selectedLocation!, 15);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location not found: $query')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
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
            'tap_map_to_set_location'.tr(),
            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
          const SizedBox(height: 12),

          // Location search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'search_location'.tr(),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textGrey),
              suffixIcon: IconButton(
                icon: const Icon(Icons.my_location_rounded, color: AppColors.primaryTeal),
                onPressed: () async {
                  try {
                    Position position = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high,
                    );
                    final lat = position.latitude;
                    final lng = position.longitude;
                    if (mounted && lat.isFinite && lng.isFinite) {
                      setState(() {
                        _selectedLocation = _clampCoordinates(lat, lng);
                      });
                      _mapController.move(_selectedLocation!, 15);
                    }
                  } catch (e) {
                    // Silently fail
                  }
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              filled: true,
              fillColor: AppColors.cardWhite,
            ),
            onSubmitted: _searchLocation,
          ),
          const SizedBox(height: 12),

          // Map for location selection
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation ?? kDefaultMapCenter,
                    initialZoom: _selectedLocation != null ? kFocusedMapZoom : kDefaultMapZoom,
                    minZoom: 4,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.doubleTapZoom,
                    ),
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLocation = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.havapaw.app',
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                      ),
                    ),
                    if (_selectedLocation != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _selectedLocation!,
                            radius: _radius,
                            useRadiusInMeter: true,
                            color: AppColors.primaryTeal.withValues(alpha: 0.2),
                            borderColor: AppColors.primaryTeal,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primaryTeal,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Current location button
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: AppColors.primaryTeal,
                    onPressed: () async {
                      try {
                        Position position = await Geolocator.getCurrentPosition(
                          desiredAccuracy: LocationAccuracy.high,
                        );
                        final lat = position.latitude;
                        final lng = position.longitude;
                        if (lat.isFinite && lng.isFinite) {
                          setState(() {
                            _selectedLocation = _clampCoordinates(lat, lng);
                          });
                          _mapController.move(_selectedLocation!, 15);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error getting location: $e')),
                          );
                        }
                      }
                    },
                    child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Form fields
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    const SizedBox(height: 20),

                    Text(
                      'radius_meters'.tr(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slateDark),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _radius,
                            min: 10,
                            max: 1000,
                            divisions: 99,
                            label: '${_radius.round()}m',
                            activeColor: AppColors.primaryTeal,
                            onChanged: (value) {
                              setState(() {
                                _radius = value;
                                _radiusCtrl.text = value.round().toString();
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            controller: _radiusCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              suffixText: 'm',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            textAlign: TextAlign.center,
                            onChanged: (value) {
                              final radius = double.tryParse(value);
                              if (radius != null && radius >= 10 && radius <= 1000) {
                                setState(() {
                                  _radius = radius;
                                });
                              }
                            },
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'required'.tr();
                              final radius = double.tryParse(v);
                              if (radius == null || radius < 10 || radius > 1000) return 'Invalid radius (10-10000 meters)';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        if (_editingGeofence != null)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _delete,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: Text('delete'.tr(), style: const TextStyle(color: Colors.red)),
                            ),
                          ),
                        if (_editingGeofence != null) const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(_editingGeofence != null ? 'update'.tr() : 'save'.tr()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}