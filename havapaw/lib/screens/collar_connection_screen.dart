import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../models/pet.dart';
import '../services/esp32_ble_service.dart';
import '../services/pet_service.dart';
import '../services/selected_pet_service.dart';
import '../theme/app_theme.dart';

class CollarConnectionScreen extends StatefulWidget {
  const CollarConnectionScreen({super.key});

  @override
  State<CollarConnectionScreen> createState() => _CollarConnectionScreenState();
}

class _CollarConnectionScreenState extends State<CollarConnectionScreen> {
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _statusMessage;
  String? _selectedRemoteId;
  List<DiscoveredCollar> _discoveredDevices = [];

  @override
  void dispose() {
    Esp32BleService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('connect_collar'.tr()),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.slateDark),
      ),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryTeal, AppColors.darkTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.bluetooth_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'esp32_collar'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'esp32_description'.tr(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'esp32_setup_hint'.tr(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isScanning || _isConnecting ? null : _startScan,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(_isScanning ? 'scanning'.tr() : 'scan'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'available_devices'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.slateDark,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isScanning
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                              color: AppColors.primaryTeal),
                          const SizedBox(height: 16),
                          Text(
                            'searching_devices'.tr(),
                            style: TextStyle(color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    )
                  : _discoveredDevices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bluetooth_disabled_rounded,
                                  size: 64,
                                  color: AppColors.textGrey
                                      .withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              Text(
                                'no_devices_found'.tr(),
                                style: TextStyle(color: AppColors.textGrey),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'tap_scan_retry'.tr(),
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textGrey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _discoveredDevices.length,
                          itemBuilder: (context, index) {
                            final device = _discoveredDevices[index];
                            final isSelected =
                                _selectedRemoteId == device.remoteId;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.cardWhite,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryTeal
                                      : AppColors.divider,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryTeal
                                            .withValues(alpha: 0.1)
                                        : AppColors.lightTeal
                                            .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.bluetooth_rounded,
                                    color: isSelected
                                        ? AppColors.primaryTeal
                                        : AppColors.slateDark,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  device.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slateDark,
                                  ),
                                ),
                                subtitle: Text(
                                  '${'esp32_device'.tr()} · ${device.rssi} dBm',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textGrey),
                                ),
                                trailing: isSelected && _isConnecting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primaryTeal,
                                        ),
                                      )
                                    : Icon(Icons.chevron_right_rounded,
                                        color: AppColors.textGrey),
                                onTap: _isConnecting
                                    ? null
                                    : () => _connectToDevice(device),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices = [];
      _statusMessage = null;
      _selectedRemoteId = null;
    });

    try {
      final devices = await Esp32BleService.scanOnce(
        timeout: const Duration(seconds: 12),
      );
      if (!mounted) return;
      setState(() {
        _discoveredDevices = devices;
        _isScanning = false;
        if (devices.isEmpty) {
          _statusMessage = 'no_devices_found_hint'.tr();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusMessage = _mapError(e);
      });
    }
  }

  Future<void> _connectToDevice(DiscoveredCollar device) async {
    final pet = await _resolveSelectedPet();
    if (pet == null || pet.id == null) {
      setState(() => _statusMessage = 'select_pet_first'.tr());
      return;
    }

    final wifi = await _askWifiCredentials();
    if (wifi == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _statusMessage = 'must_be_signed_in'.tr());
      return;
    }

    setState(() {
      _selectedRemoteId = device.remoteId;
      _isConnecting = true;
      _statusMessage = 'provisioning_collar'.tr();
    });

    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      final collarId = await Esp32BleService.provisionAndBind(
        collar: device,
        payload: CollarProvisionPayload(
          wifiSsid: wifi.$1,
          wifiPassword: wifi.$2,
          ownerUid: uid,
          petId: pet.id!,
          projectId: options.projectId,
          apiKey: options.apiKey,
          deviceId: device.name,
        ),
      );

      await PetService.updatePet(pet.id!, {'collarId': collarId});

      // Seed a lightweight "connected" reading so Health leaves the empty state
      // until the ESP32 posts its first real sample over WiFi.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('collarData')
          .add({
        'deviceId': collarId,
        'deviceName': device.name,
        'petId': pet.id,
        'timestamp': DateTime.now().toIso8601String(),
        'batteryLevel': null,
        'heartRate': null,
        'temperature': null,
        'steps': null,
      });

      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _statusMessage = null;
      });
      _showConnectionSuccessDialog(collarId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _statusMessage = _mapError(e);
      });
    }
  }

  Future<Pet?> _resolveSelectedPet() async {
    final snap = await PetService.getPetsStream().first;
    final pets = snap.docs
        .map((d) => Pet.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
    if (pets.isEmpty) return null;
    SelectedPetService.ensureValidSelection(pets.map((p) => p.id!).toList());
    final id = SelectedPetService.selectedPetId;
    return pets.firstWhere((p) => p.id == id, orElse: () => pets.first);
  }

  Future<(String, String)?> _askWifiCredentials() async {
    final ssidCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var obscure = true;

    return showDialog<(String, String)>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('wifi_credentials_title'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'wifi_credentials_desc'.tr(),
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ssidCtrl,
                    decoration: InputDecoration(
                      labelText: 'wifi_ssid'.tr(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'wifi_password'.tr(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setLocal(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('cancel'.tr()),
                ),
                TextButton(
                  onPressed: () {
                    final ssid = ssidCtrl.text.trim();
                    if (ssid.isEmpty) return;
                    Navigator.pop(ctx, (ssid, passCtrl.text));
                  },
                  child: Text('continue'.tr(),
                      style: const TextStyle(color: AppColors.primaryTeal)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _mapError(Object e) {
    final key = e is StateError ? e.message : e.toString();
    switch (key) {
      case 'bluetooth_not_available':
        return 'bluetooth_not_available'.tr();
      case 'bluetooth_off':
        return 'bluetooth_off'.tr();
      case 'bluetooth_permissions_required':
        return 'bluetooth_permissions_required'.tr();
      case 'connection_failed':
        return 'connection_failed'.tr();
      case 'gatt_service_missing':
      case 'gatt_config_missing':
        return 'gatt_service_missing'.tr();
      default:
        if (key.contains('WIFI_FAIL')) return 'wifi_connect_failed'.tr();
        if (key.contains('FIREBASE_FAIL')) return 'firebase_sync_failed'.tr();
        return key;
    }
  }

  void _showConnectionSuccessDialog(String collarId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.lightTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.primaryTeal, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'connection_success'.tr(),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateDark),
            ),
            const SizedBox(height: 8),
            Text(
              'collar_connected_desc'.tr(),
              style: TextStyle(fontSize: 14, color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              collarId,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryTeal,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr(),
                style: const TextStyle(color: AppColors.primaryTeal)),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) Navigator.pop(context);
    });
  }
}
