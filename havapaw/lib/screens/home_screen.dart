import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../widgets/bottom_nav.dart';
import '../theme/app_theme.dart';
import '../services/pet_service.dart';
import '../services/selected_pet_service.dart';
import '../services/collar_data_service.dart';
import '../services/geofence_service.dart';
import '../services/pet_location_service.dart';
import '../services/sound_service.dart';
import '../models/pet.dart';
import '../models/collar_data.dart';
import '../models/geofence.dart';
import '../utils/map_defaults.dart';
import 'health_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _HomeTab(),
    HealthScreen(),
    MapScreen(),
    ProfileScreen(),
  ];

  // Starts background music when the home screen opens.
  @override
  void initState() {
    super.initState();
    if (SoundService.isMusicEnabled) {
      SoundService.playBackgroundMusic();
    }
  }

  // Stops background music when leaving the home screen.
  @override
  void dispose() {
    SoundService.stopBackgroundMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

// ─── Home Tab ────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _user = FirebaseAuth.instance.currentUser;
  Position? _currentPosition;
  bool _isOnWalk = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Shows a warning when the pet leaves the safe zone.
  void _showGeofenceAlertDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.alertRed),
            const SizedBox(width: 8),
            Text('pet_outside_zone_alert'.tr()),
          ],
        ),
        content: Text('pet_outside_zone_desc'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isOnWalk = true);
            },
            child: Text('on_walk'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('dismiss'.tr()),
          ),
        ],
      ),
    );
  }

  // Gets the user's current GPS location for the map preview.
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    } catch (e) {
      // Silently fail for preview
    }
  }

  // Calculates a simple health score from collar data.
  int _calculateHealthScore(CollarData data) {
    int score = 100;
    
    // Deduct points based on heart rate
    if (data.heartRate != null) {
      if (data.heartRate! < 60 || data.heartRate! > 120) {
        score -= 20;
      } else if (data.heartRate! < 70 || data.heartRate! > 110) {
        score -= 10;
      }
    }
    
    // Deduct points based on temperature
    if (data.temperature != null) {
      if (data.temperature! < 36.0 || data.temperature! > 40.0) {
        score -= 20;
      } else if (data.temperature! < 36.5 || data.temperature! > 39.0) {
        score -= 10;
      }
    }
    
    // Deduct points based on activity (steps)
    if (data.steps != null) {
      if (data.steps! < 3000) {
        score -= 15;
      } else if (data.steps! < 5000) {
        score -= 5;
      }
    }
    
    return score.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _user?.displayName ?? 'there';
    final firstName = fullName.split(' ')[0];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🐾 Hi $firstName!',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slateDark,
                        ),
                      ),
                      Text(
                        'welcome_back'.tr(),
                        style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                      ),
                    ],
                  ),
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

            // Pet card
            ValueListenableBuilder<int>(
              valueListenable: SelectedPetService.notifier,
              builder: (context, _, child) {
                return StreamBuilder<QuerySnapshot>(
              stream: PetService.getPetsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading pets'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
                }
                if (snapshot.data!.docs.isEmpty) {
                  return _EmptyPetCard();
                }
                final pets = snapshot.data!.docs
                    .map((doc) => Pet.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();
                final petIds = pets.map((pet) => pet.id!).toList();
                SelectedPetService.ensureValidSelection(petIds);
                final activePetIndex = SelectedPetService.activeIndex(petIds);
                final pet = pets[activePetIndex];
                return Column(
                  children: [
                    GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! > 0) {
                            SelectedPetService.selectPrevious(petIds);
                          } else {
                            SelectedPetService.selectNext(petIds);
                          }
                        }
                      },
                      child: _PetCard(
                        pet: pet,
                        totalPets: pets.length,
                        currentIndex: activePetIndex,
                        onPrev: () => SelectedPetService.selectPrevious(petIds),
                        onNext: () => SelectedPetService.selectNext(petIds),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Map preview
                    _SectionCard(
                      child: StreamBuilder<List<Geofence>>(
                        stream: pet.id != null ? GeofenceService.getGeofencesForPet(pet.id!) : Stream.value([]),
                        builder: (context, geofenceSnapshot) {
                          final geofences = geofenceSnapshot.data ?? [];
                          
                          // Get pet's actual location from PetLocationService
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

                              // Check if pet is outside geofence
                              bool isOutside = false;
                              if (geofences.isNotEmpty && hasPetLocation) {
                                isOutside = !GeofenceService.isPetWithinGeofence(petLocation, geofences.first);
                              }

                              LatLng mapCenter = kDefaultMapCenter;
                              double mapZoom = kDefaultMapZoom;
                              if (hasUserLocation) {
                                mapCenter = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
                                mapZoom = 14;
                              } else if (hasPetLocation) {
                                mapCenter = petLocation;
                                mapZoom = 14;
                              } else if (geofences.isNotEmpty) {
                                final geofence = geofences.first;
                                if (geofence.latitude.isFinite && geofence.longitude.isFinite) {
                                  mapCenter = LatLng(geofence.latitude, geofence.longitude);
                                  mapZoom = 14;
                                }
                              }
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_rounded, color: (isOutside && !_isOnWalk) ? AppColors.alertRed : AppColors.primaryTeal, size: 18),
                                          const SizedBox(width: 6),
                                          Text('current_location'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.slateDark)),
                                        ],
                                      ),
                                      if (geofences.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.lightTeal,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text('no_safe_zone'.tr(), style: const TextStyle(color: AppColors.primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
                                        )
                                      else if (isOutside && !_isOnWalk)
                                        GestureDetector(
                                          onTap: () => _showGeofenceAlertDialog(),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.alertRed.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: AppColors.alertRed),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.warning_rounded, color: AppColors.alertRed, size: 12),
                                                const SizedBox(width: 4),
                                                Text('pet_outside_zone'.tr(), style: const TextStyle(color: AppColors.alertRed, fontSize: 11, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                        )
                                      else if (_isOnWalk)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.amber),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.directions_walk_rounded, color: Colors.amber, size: 12),
                                              const SizedBox(width: 4),
                                              Text('on_walk'.tr(), style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.lightTeal,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text('safe_zone'.tr(), style: const TextStyle(color: AppColors.primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 150,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: FlutterMap(
                                        options: MapOptions(
                                          initialCenter: mapCenter,
                                          initialZoom: mapZoom,
                                          minZoom: 4,
                                          maxZoom: 18,
                                          interactionOptions: const InteractionOptions(
                                            flags: InteractiveFlag.none,
                                          ),
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                            userAgentPackageName: 'com.havapaw.app',
                                          ),
                                          // Geofence circles
                                          if (geofences.isNotEmpty)
                                            CircleLayer(
                                              circles: geofences.map((g) {
                                                final lat = g.latitude;
                                                final lng = g.longitude;
                                                if (!lat.isFinite || !lng.isFinite) return null;
                                                return CircleMarker(
                                                  point: LatLng(lat, lng),
                                                  radius: g.radius,
                                                  color: isOutside && !_isOnWalk ? AppColors.alertRed.withValues(alpha: 0.2) : AppColors.primaryTeal.withValues(alpha: 0.2),
                                                  borderColor: isOutside && !_isOnWalk ? AppColors.alertRed : AppColors.primaryTeal,
                                                  borderStrokeWidth: 2,
                                                );
                                              }).whereType<CircleMarker>().toList(),
                                            ),
                                          // User location marker
                                          if (hasUserLocation)
                                            MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                                  width: 30,
                                                  height: 30,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.withValues(alpha: 0.3),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.my_location_rounded,
                                                      color: Colors.blue,
                                                      size: 16,
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
                                                width: 30,
                                                height: 30,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isOutside && !_isOnWalk ? AppColors.alertRed.withValues(alpha: 0.3) : AppColors.primaryTeal.withValues(alpha: 0.3),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.pets_rounded,
                                                    color: isOutside && !_isOnWalk ? AppColors.alertRed : AppColors.primaryTeal,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!hasUserLocation && !hasPetLocation) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      'map_location_hint'.tr(),
                                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4),
                                    ),
                                  ],
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Health score and stats from pet collar
                    StreamBuilder<CollarData?>(
                      stream: pet.id != null ? CollarDataService.getLatestCollarDataForPet(pet.id!) : Stream.value(null),
                      builder: (context, snapshot) {
                        final collarData = snapshot.data;
                        
                        // Calculate health score based on collar data
                        int healthScore = 100;
                        if (collarData != null) {
                          healthScore = _calculateHealthScore(collarData);
                        }
                        
                        return Column(
                          children: [
                            // Health score
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.favorite_rounded, color: AppColors.primaryTeal, size: 18),
                                      const SizedBox(width: 6),
                                      Text('health_score'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.slateDark)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: healthScore / 100,
                                            backgroundColor: AppColors.divider,
                                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryTeal),
                                            minHeight: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text('$healthScore/100', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryTeal, fontSize: 16)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Activity breakdown - only show if collar data is available
                            if (collarData != null)
                              _SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('activity_breakdown'.tr(), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.slateDark)),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _StatCard(icon: Icons.directions_walk_rounded, label: 'steps'.tr(), value: collarData?.steps?.toString() ?? '--', unit: '/ 10,000', color: AppColors.primaryTeal),
                                        const SizedBox(width: 12),
                                        _StatCard(icon: Icons.straighten_rounded, label: 'distance'.tr(), value: collarData?.distance?.toStringAsFixed(1) ?? '--', unit: 'km today', color: AppColors.darkTeal),
                                        const SizedBox(width: 12),
                                        _StatCard(icon: Icons.local_fire_department_rounded, label: 'calories'.tr(), value: collarData?.calories?.toString() ?? '--', unit: 'kcal', color: AppColors.amber),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            if (collarData == null)
                              _SectionCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.watch_outlined, size: 40, color: AppColors.textGrey.withValues(alpha: 0.5)),
                                        const SizedBox(height: 8),
                                        Text('connect_smartwatch'.tr(), style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
          ],
        ),
      ),
    );
          },
        );
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

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

class _PetCard extends StatelessWidget {
  final Pet pet;
  final int totalPets;
  final int currentIndex;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _PetCard({
    required this.pet,
    required this.totalPets,
    required this.currentIndex,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryTeal, AppColors.darkTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (totalPets > 1)
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
            ),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 2),
                  ),
                  child: pet.imageBase64 != null && pet.imageBase64!.isNotEmpty
                      ? ClipOval(
                          child: Image.memory(
                            base64Decode(pet.imageBase64!),
                            fit: BoxFit.cover,
                            width: 70,
                            height: 70,
                            errorBuilder: (context, error, stackTrace) {
                              return ClipOval(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              );
                            },
                          ),
                        )
                      : ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(pet.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                Text(pet.breed, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (totalPets > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      totalPets,
                      (i) => Container(
                        width: i == currentIndex ? 16 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i == currentIndex ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (totalPets > 1)
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

class _EmptyPetCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.lightTeal,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkTeal.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('no_pets_yet'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.slateDark, fontSize: 16)),
          Text('add_first_pet'.tr(), style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ActivityRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            Text(unit, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
