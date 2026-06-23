import 'package:flutter_blue_plus/flutter_blue_plus.dart' as flutter_blue_plus;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/watch_data.dart';

class BluetoothService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isScanning = false;
  flutter_blue_plus.BluetoothDevice? _connectedDevice;
  final List<flutter_blue_plus.BluetoothDevice> _discoveredDevices = [];
  
  bool get isScanning => _isScanning;
  flutter_blue_plus.BluetoothDevice? get connectedDevice => _connectedDevice;
  List<flutter_blue_plus.BluetoothDevice> get discoveredDevices => _discoveredDevices;
  
  // Request Bluetooth permissions
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    
    return statuses.values.every((status) => status.isGranted);
  }
  
  // Check if Bluetooth is available and enabled
  Future<bool> isBluetoothAvailable() async {
    if (await flutter_blue_plus.FlutterBluePlus.isSupported == false) {
      return false;
    }
    await flutter_blue_plus.FlutterBluePlus.turnOn();
    return true;
  }
  
  // Start scanning for devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isScanning) return;
    
    _isScanning = true;
    _discoveredDevices.clear();
    
    try {
      await flutter_blue_plus.FlutterBluePlus.startScan(timeout: timeout);
      
      flutter_blue_plus.FlutterBluePlus.scanResults.listen((results) {
        for (flutter_blue_plus.ScanResult r in results) {
          if (!_discoveredDevices.contains(r.device)) {
            _discoveredDevices.add(r.device);
          }
        }
      });
    } catch (e) {
      _isScanning = false;
      rethrow;
    }
  }
  
  // Stop scanning
  Future<void> stopScan() async {
    _isScanning = false;
    await flutter_blue_plus.FlutterBluePlus.stopScan();
  }
  
  // Connect to a device
  Future<void> connectToDevice(flutter_blue_plus.BluetoothDevice device) async {
    try {
      await device.connect();
      _connectedDevice = device;
      
      // Listen to connection state
      device.connectionState.listen((state) {
        if (state == flutter_blue_plus.BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
        }
      });
    } catch (e) {
      rethrow;
    }
  }
  
  // Disconnect from device
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
  }
  
  // Discover services
  Future<List<flutter_blue_plus.BluetoothService>> discoverServices() async {
    if (_connectedDevice == null) return [];
    return await _connectedDevice!.discoverServices();
  }
  
  // Read data from a characteristic
  Future<List<int>> readCharacteristic(flutter_blue_plus.BluetoothCharacteristic characteristic) async {
    return await characteristic.read();
  }
  
  // Write data to a characteristic
  Future<void> writeCharacteristic(flutter_blue_plus.BluetoothCharacteristic characteristic, List<int> data) async {
    await characteristic.write(data);
  }
  
  // Subscribe to characteristic notifications
  Stream<List<int>> subscribeToCharacteristic(flutter_blue_plus.BluetoothCharacteristic characteristic) {
    characteristic.setNotifyValue(true);
    return characteristic.lastValueStream;
  }
  
  // Sync watch data to Firebase
  Future<void> syncWatchData(WatchData watchData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).collection('watchData').add({
        ...watchData.toMap(),
        'syncedAt': FieldValue.serverTimestamp(),
      });

      if (watchData.petId != null && watchData.steps != null) {
        await _db
            .collection('users')
            .doc(uid)
            .collection('pets')
            .doc(watchData.petId)
            .update({
          'lastSyncedAt': FieldValue.serverTimestamp(),
          'steps': watchData.steps,
        });
      }
      print('Watch data synced');
    } catch (e) {
      print('Error syncing watch data: $e');
    }
  }
  
  // Get watch data history
  Stream<QuerySnapshot> getWatchDataHistory({int limit = 50}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    
    return _db
        .collection('users')
        .doc(uid)
        .collection('watchData')
        .orderBy('syncedAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}
