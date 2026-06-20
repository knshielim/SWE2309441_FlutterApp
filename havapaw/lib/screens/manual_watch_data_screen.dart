import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/bluetooth_service.dart';
import '../models/watch_data.dart';
import '../models/pet.dart';
import '../services/pet_service.dart';

class ManualWatchDataScreen extends StatefulWidget {
  const ManualWatchDataScreen({super.key});

  @override
  State<ManualWatchDataScreen> createState() => _ManualWatchDataScreenState();
}

class _ManualWatchDataScreenState extends State<ManualWatchDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bluetoothService = BluetoothService();
  final _petService = PetService();
  
  final _stepsController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _distanceController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _temperatureController = TextEditingController();
  
  String? _selectedPetId;
  List<Pet> _pets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  @override
  void dispose() {
    _stepsController.dispose();
    _heartRateController.dispose();
    _distanceController.dispose();
    _caloriesController.dispose();
    _temperatureController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    final snapshot = await _petService.getPetsStream().first;
    final pets = snapshot.docs
        .map((doc) => Pet.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
    if (mounted) {
      setState(() {
        _pets = pets;
        if (pets.isNotEmpty) {
          _selectedPetId = pets.first.id;
        }
      });
    }
  }

  Future<void> _saveWatchData() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final watchData = WatchData(
        deviceId: 'manual_entry',
        deviceName: 'Manual Entry',
        steps: int.tryParse(_stepsController.text),
        heartRate: int.tryParse(_heartRateController.text),
        distance: double.tryParse(_distanceController.text),
        calories: int.tryParse(_caloriesController.text),
        temperature: double.tryParse(_temperatureController.text),
        timestamp: DateTime.now(),
        petId: _selectedPetId,
      );

      await _bluetoothService.syncWatchData(watchData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Watch data saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Watch Data Entry'),
        backgroundColor: AppColors.primaryTeal,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightTeal,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primaryTeal, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Manual Entry',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.slateDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your watch data from the Laxasfit app manually. This data will be synced to Firebase.',
                        style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Pet selection
                if (_pets.isNotEmpty) ...[
                  _label('Select Pet'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPetId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.cardWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: _pets.map((pet) {
                      return DropdownMenuItem(
                        value: pet.id,
                        child: Text('${pet.name} (${pet.type})'),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedPetId = value),
                  ),
                  const SizedBox(height: 20),
                ],

                // Steps
                _label('Steps'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _stepsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 7500',
                    prefixIcon: Icon(Icons.directions_walk_rounded, color: AppColors.textGrey),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final steps = int.tryParse(v);
                    if (steps == null || steps < 0) return 'Invalid steps value';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Heart Rate
                _label('Heart Rate (bpm)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _heartRateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 85',
                    prefixIcon: Icon(Icons.favorite_rounded, color: AppColors.textGrey),
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final heartRate = int.tryParse(v);
                      if (heartRate == null || heartRate < 0 || heartRate > 250) return 'Invalid heart rate (0-250)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Distance
                _label('Distance (km)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _distanceController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 5.2',
                    prefixIcon: Icon(Icons.straighten_rounded, color: AppColors.textGrey),
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final distance = double.tryParse(v);
                      if (distance == null || distance < 0) return 'Invalid distance value';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Calories
                _label('Calories (kcal)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 350',
                    prefixIcon: Icon(Icons.local_fire_department_rounded, color: AppColors.textGrey),
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final calories = int.tryParse(v);
                      if (calories == null || calories < 0) return 'Invalid calories value';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Temperature
                _label('Temperature (°C)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _temperatureController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 36.5',
                    prefixIcon: Icon(Icons.thermostat_rounded, color: AppColors.textGrey),
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final temp = double.tryParse(v);
                      if (temp == null || temp < 30 || temp > 45) return 'Invalid temperature (30-45°C)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveWatchData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Save Data'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slateDark),
      );
}
