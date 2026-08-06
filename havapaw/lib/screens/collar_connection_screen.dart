import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../services/selected_pet_service.dart';
import '../models/pet.dart';

class CollarConnectionScreen extends StatefulWidget {
  const CollarConnectionScreen({super.key});

  @override
  State<CollarConnectionScreen> createState() => _CollarConnectionScreenState();
}

class _CollarConnectionScreenState extends State<CollarConnectionScreen> {
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _selectedDevice;
  final List<String> _discoveredDevices = [
    'HavaPaw-ESP32-1234',
    'HavaPaw-ESP32-5678',
  ];

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
            // Info card
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
                        child: const Icon(Icons.bluetooth_rounded, color: Colors.white, size: 24),
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
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Scan button
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _startScan,
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
            const SizedBox(height: 24),

            // Discovered devices
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
                          CircularProgressIndicator(color: AppColors.primaryTeal),
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
                              Icon(Icons.bluetooth_disabled_rounded, size: 64, color: AppColors.textGrey.withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              Text(
                                'no_devices_found'.tr(),
                                style: TextStyle(color: AppColors.textGrey),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'tap_scan_retry'.tr(),
                                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _discoveredDevices.length,
                          itemBuilder: (context, index) {
                            final device = _discoveredDevices[index];
                            final isSelected = _selectedDevice == device;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.cardWhite,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryTeal : AppColors.divider,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryTeal.withValues(alpha: 0.1)
                                        : AppColors.lightTeal.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.bluetooth_rounded,
                                    color: isSelected ? AppColors.primaryTeal : AppColors.slateDark,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  device,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slateDark,
                                  ),
                                ),
                                subtitle: Text(
                                  'esp32_device'.tr(),
                                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                                ),
                                trailing: isSelected
                                    ? _isConnecting
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primaryTeal,
                                            ),
                                          )
                                        : Icon(Icons.check_circle_rounded, color: AppColors.primaryTeal)
                                    : Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
                                onTap: () => _connectToDevice(device),
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

  void _startScan() {
    setState(() => _isScanning = true);
    // Simulate scanning delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    });
  }

  void _connectToDevice(String device) {
    setState(() {
      _selectedDevice = device;
      _isConnecting = true;
    });

    // Simulate connection delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isConnecting = false);
        _showConnectionSuccessDialog();
      }
    });
  }

  void _showConnectionSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: AppColors.primaryTeal, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'connection_success'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
            ),
            const SizedBox(height: 8),
            Text(
              'collar_connected_desc'.tr(),
              style: TextStyle(fontSize: 14, color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr(), style: const TextStyle(color: AppColors.primaryTeal)),
          ),
        ],
      ),
    ).then((_) {
      Navigator.pop(context);
    });
  }
}
