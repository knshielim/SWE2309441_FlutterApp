import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../theme/app_theme.dart';
import '../services/pet_location_service.dart';
import '../services/selected_pet_service.dart';
import '../utils/map_defaults.dart';

class PetLocationScreen extends StatefulWidget {
  const PetLocationScreen({super.key});

  @override
  State<PetLocationScreen> createState() => _PetLocationScreenState();
}

class _PetLocationScreenState extends State<PetLocationScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  bool _isLoading = false;
  String _address = '';

  // Keeps map coordinates inside valid latitude and longitude ranges.
  LatLng _clampCoordinates(double lat, double lng) {
    final clampedLat = lat.clamp(-85.0, 85.0);
    final clampedLng = lng.clamp(-180.0, 180.0);
    return LatLng(clampedLat, clampedLng);
  }

  // Gets the user's current GPS location and moves the map there.
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
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
            _selectedLocation = _clampCoordinates(lat, lng);
          });
          _mapController.move(_selectedLocation!, kFocusedMapZoom);
          _getAddressFromCoordinates(_selectedLocation!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid location coordinates'.tr())),
          );
        }
      }
    } catch (_) {
      // Location may be unavailable on some devices.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Converts map coordinates into a readable street address.
  Future<void> _getAddressFromCoordinates(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _address = '${place.street}, ${place.locality}, ${place.country}';
        });
      }
    } catch (_) {
      // Address lookup may fail for some coordinates.
    }
  }

  // Saves the selected location for the current pet.
  Future<void> _saveLocation() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a location'.tr())),
      );
      return;
    }

    final petId = SelectedPetService.selectedPetId;
    if (petId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pet selected'.tr())),
      );
      return;
    }

    try {
      await PetLocationService.updatePetLocation(petId, _selectedLocation!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pet location saved'.tr())),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving location: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('set_pet_location'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: kDefaultMapCenter,
                initialZoom: kDefaultMapZoom,
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedLocation = point;
                  });
                  _getAddressFromCoordinates(point);
                  _mapController.move(point, kFocusedMapZoom);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.havapaw.app',
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.pets,
                          color: AppColors.primaryTeal,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightTeal,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.primaryTeal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'map_tap_to_set_location'.tr(),
                          style: const TextStyle(fontSize: 13, color: AppColors.slateDark, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_address.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'selected_address'.tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.slateDark,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _getCurrentLocation,
                        child: Text('get_current_location'.tr()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveLocation,
                        child: Text('save_location'.tr()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
