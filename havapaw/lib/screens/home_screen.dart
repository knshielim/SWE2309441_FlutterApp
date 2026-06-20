import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import '../widgets/bottom_nav.dart';
import '../theme/app_theme.dart';
import '../services/pet_service.dart';
import '../services/watch_data_service.dart';
import '../models/pet.dart';
import '../models/watch_data.dart';
import 'health_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'account_settings_screen.dart';

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
  final _petService = PetService();
  final _watchDataService = WatchDataService();
  final _user = FirebaseAuth.instance.currentUser;
  int _activePetIndex = 0;

  int _calculateHealthScore(WatchData data) {
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
                    MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
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
            StreamBuilder<List<Pet>>(
              stream: _petService.getPets(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
                }
                final pets = snapshot.data ?? [];
                if (pets.isEmpty) {
                  return _EmptyPetCard();
                }
                if (_activePetIndex >= pets.length) _activePetIndex = 0;
                final pet = pets[_activePetIndex];
                return GestureDetector(
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
                  child: _PetCard(
                    pet: pet,
                    totalPets: pets.length,
                    currentIndex: _activePetIndex,
                    onPrev: () {
                      setState(() => _activePetIndex = (_activePetIndex - 1 + pets.length) % pets.length);
                    },
                    onNext: () {
                      setState(() => _activePetIndex = (_activePetIndex + 1) % pets.length);
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Map preview
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: AppColors.primaryTeal, size: 18),
                          const SizedBox(width: 6),
                          Text('current_location'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.slateDark)),
                        ],
                      ),
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
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.lightTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.map_rounded, color: AppColors.primaryTeal, size: 36),
                          const SizedBox(height: 6),
                          Text('map_preview'.tr(), style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w600)),
                          Text('connect_gps_collar'.tr(), style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Health score and stats from smartwatch
            StreamBuilder<WatchData?>(
              stream: _watchDataService.getLatestWatchData(),
              builder: (context, snapshot) {
                final watchData = snapshot.data;
                
                // Calculate health score based on watch data
                int healthScore = 100;
                if (watchData != null) {
                  healthScore = _calculateHealthScore(watchData);
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

                    // Activity breakdown - only show if watch data is available
                    if (watchData != null)
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('activity_breakdown'.tr(), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.slateDark)),
                            const SizedBox(height: 12),
                            _ActivityRow(icon: Icons.bedtime_rounded, label: 'sleep'.tr(), value: '8.5 hours', color: AppColors.darkTeal),
                            const SizedBox(height: 8),
                            _ActivityRow(icon: Icons.directions_walk_rounded, label: 'walk'.tr(), value: '2.3 hours', color: AppColors.primaryTeal),
                            const SizedBox(height: 8),
                            _ActivityRow(icon: Icons.pause_circle_rounded, label: 'idle'.tr(), value: '13.2 hours', color: AppColors.textGrey),
                          ],
                        ),
                      ),
                    if (watchData == null)
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
                    const SizedBox(height: 16),

                    // Stats row
                    Row(
                      children: [
                        _StatCard(icon: Icons.directions_walk_rounded, label: 'steps'.tr(), value: watchData?.steps?.toString() ?? '--', unit: '/ 10,000', color: AppColors.primaryTeal),
                        const SizedBox(width: 12),
                        _StatCard(icon: Icons.straighten_rounded, label: 'distance'.tr(), value: watchData?.distance?.toStringAsFixed(1) ?? '--', unit: 'km today', color: AppColors.darkTeal),
                        const SizedBox(width: 12),
                        _StatCard(icon: Icons.local_fire_department_rounded, label: 'calories'.tr(), value: watchData?.calories?.toString() ?? '--', unit: 'kcal', color: AppColors.amber),
                      ],
                    ),
                    const SizedBox(height: 20),
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
                              return const Icon(Icons.pets, color: Colors.white, size: 38);
                            },
                          ),
                        )
                      : const Icon(Icons.pets, color: Colors.white, size: 38),
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
          const Icon(Icons.pets, color: AppColors.primaryTeal, size: 40),
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
