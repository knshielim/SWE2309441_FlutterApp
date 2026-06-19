import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as flutter_blue_plus;
import '../theme/app_theme.dart';
import '../services/bluetooth_service.dart';
import '../models/watch_data.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  bool _isScanning = false;
  bool _isConnected = false;
  List<flutter_blue_plus.BluetoothDevice> _devices = [];
  flutter_blue_plus.BluetoothDevice? _connectedDevice;
  String _status = 'not_connected'.tr();

  @override
  void initState() {
    super.initState();
    _checkBluetooth();
    _checkConnectionState();
  }

  Future<void> _checkBluetooth() async {
    final available = await _bluetoothService.isBluetoothAvailable();
    if (!available && mounted) {
      setState(() => _status = 'bluetooth_not_available'.tr());
    }
  }

  Future<void> _checkConnectionState() async {
    // Check if there's already a connected device
    final connectedDevice = _bluetoothService.connectedDevice;
    if (connectedDevice != null && mounted) {
      setState(() {
        _connectedDevice = connectedDevice;
        _isConnected = true;
        _status = 'Connected to ${connectedDevice.platformName}';
      });
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await _bluetoothService.requestPermissions();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('bluetooth_permissions_required'.tr())),
      );
    }
  }

  Future<void> _startScan() async {
    await _requestPermissions();
    
    setState(() {
      _isScanning = true;
      _devices.clear();
      _status = 'Scanning...';
    });

    try {
      await _bluetoothService.startScan(timeout: const Duration(seconds: 10));
      
      // Listen for scan results
      flutter_blue_plus.FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _devices = results.map((r) => r.device).toList();
          });
        }
      });

      // Stop scan after timeout
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _isScanning) {
          _stopScan();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _status = 'Scan failed: $e';
        });
      }
    }
  }

  Future<void> _stopScan() async {
    await _bluetoothService.stopScan();
    if (mounted) {
      setState(() {
        _isScanning = false;
        _status = _devices.isEmpty ? 'No devices found' : 'Scan complete';
      });
    }
  }

  Future<void> _connectToDevice(flutter_blue_plus.BluetoothDevice device) async {
    setState(() => _status = 'Connecting to ${device.platformName}...');
    
    try {
      await _bluetoothService.connectToDevice(device);
      setState(() {
        _connectedDevice = device;
        _isConnected = true;
        _status = 'Connected to ${device.platformName}';
      });
      
      // Start listening for data
      _listenToDeviceData(device);
    } catch (e) {
      setState(() => _status = 'Connection failed: $e');
    }
  }

  Future<void> _disconnect() async {
    await _bluetoothService.disconnect();
    setState(() {
      _connectedDevice = null;
      _isConnected = false;
      _status = 'Disconnected';
    });
  }

  void _listenToDeviceData(flutter_blue_plus.BluetoothDevice device) {
    // Discover services and listen for data
    device.discoverServices().then((services) {
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // Subscribe to notifications
          characteristic.setNotifyValue(true);
          characteristic.lastValueStream.listen((data) {
            // Parse and sync data to Firebase
            _handleWatchData(data);
          });
        }
      }
    });
  }

  Future<void> _handleWatchData(List<int> data) {
    // Parse data from smartwatch using WatchData model
    final deviceId = _connectedDevice?.remoteId.toString() ?? 'unknown';
    final deviceName = _connectedDevice?.platformName ?? 'Unknown Device';
    
    final watchData = WatchData.parseBluetoothData(
      data,
      deviceId,
      deviceName,
    );
    
    if (watchData != null) {
      // Sync to Firebase
      return _bluetoothService.syncWatchData(watchData);
    }
    
    return Future.value();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('smartwatch_connection'.tr()),
        backgroundColor: AppColors.primaryTeal,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status card
              _StatusCard(
                status: _status,
                isConnected: _isConnected,
                deviceName: _connectedDevice?.platformName,
              ),
              const SizedBox(height: 20),

              // Scan button
              if (!_isConnected)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? _stopScan : _startScan,
                    icon: Icon(_isScanning ? Icons.stop : Icons.bluetooth_searching),
                    label: Text(_isScanning ? 'stop_scan'.tr() : 'scan'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

              if (_isScanning) ...[
                const SizedBox(height: 20),
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryTeal),
                ),
              ],

              const SizedBox(height: 20),

              // Device list
              if (_devices.isNotEmpty && !_isConnected)
                Expanded(
                  child: ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return _DeviceCard(
                        device: device,
                        onTap: () => _connectToDevice(device),
                      );
                    },
                  ),
                ),

              // Connected device info
              if (_isConnected) ...[
                const SizedBox(height: 20),
                _ConnectedDeviceCard(
                  device: _connectedDevice!,
                  onDisconnect: _disconnect,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  final bool isConnected;
  final String? deviceName;

  const _StatusCard({
    required this.status,
    required this.isConnected,
    this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected ? AppColors.lightTeal : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? AppColors.primaryTeal : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: isConnected ? AppColors.primaryTeal : AppColors.textGrey,
              ),
              const SizedBox(width: 10),
              Text(
                'connection_status'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.slateDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isConnected ? AppColors.primaryTeal : AppColors.textGrey,
            ),
          ),
          if (deviceName != null) ...[
            const SizedBox(height: 5),
            Text(
              '${'device'.tr()}: $deviceName',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final flutter_blue_plus.BluetoothDevice device;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: const Icon(Icons.watch, color: AppColors.primaryTeal),
        title: Text(
          device.platformName.isNotEmpty ? device.platformName : 'unknown_device'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(device.remoteId.toString()),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _ConnectedDeviceCard extends StatelessWidget {
  final flutter_blue_plus.BluetoothDevice device;
  final VoidCallback onDisconnect;

  const _ConnectedDeviceCard({
    required this.device,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryTeal, AppColors.darkTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.watch, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            device.platformName.isNotEmpty ? device.platformName : 'connected_device'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'syncing_data'.tr(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDisconnect,
              icon: const Icon(Icons.bluetooth_disabled, color: Colors.white),
              label: Text('disconnect'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
