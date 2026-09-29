import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'collar_ble_protocol.dart';

/// A BLE collar seen during scanning.
class DiscoveredCollar {
  final String remoteId;
  final String name;
  final int rssi;
  final BluetoothDevice device;

  const DiscoveredCollar({
    required this.remoteId,
    required this.name,
    required this.rssi,
    required this.device,
  });
}

/// Payload written to the ESP32 over BLE so it can join WiFi and write Firestore.
class CollarProvisionPayload {
  final String wifiSsid;
  final String wifiPassword;
  final String ownerUid;
  final String petId;
  final String projectId;
  final String apiKey;
  final String deviceId;

  const CollarProvisionPayload({
    required this.wifiSsid,
    required this.wifiPassword,
    required this.ownerUid,
    required this.petId,
    required this.projectId,
    required this.apiKey,
    required this.deviceId,
  });

  String toJsonString() => jsonEncode({
        'ssid': wifiSsid,
        'pass': wifiPassword,
        'uid': ownerUid,
        'petId': petId,
        'projectId': projectId,
        'apiKey': apiKey,
        'deviceId': deviceId,
      });
}

/// Real BLE scan / connect / WiFi-provision flow for HavaPaw ESP32 collars.
class Esp32BleService {
  Esp32BleService._();

  static StreamSubscription<List<ScanResult>>? _scanSub;
  static final Map<String, DiscoveredCollar> _found = {};

  static Future<bool> isBluetoothOn() async {
    try {
      return await FlutterBluePlus.isSupported &&
          await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  /// Requests platform permissions needed for BLE scanning.
  static Future<bool> ensurePermissions() async {
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    final statuses = await permissions.request();
    final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? true;
    final connectOk = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
    final locationOk =
        statuses[Permission.locationWhenInUse]?.isGranted ?? false;

    // Location is required on many Android versions for BLE scan results.
    return scanOk && connectOk && locationOk;
  }

  /// Starts a scan and emits the growing list of likely collar devices.
  static Stream<List<DiscoveredCollar>> scan({
    Duration timeout = const Duration(seconds: 12),
  }) async* {
    await stopScan();
    _found.clear();

    if (!await FlutterBluePlus.isSupported) {
      throw StateError('bluetooth_not_available');
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {
        throw StateError('bluetooth_off');
      }
    }

    if (!await ensurePermissions()) {
      throw StateError('bluetooth_permissions_required');
    }

    final controller = StreamController<List<DiscoveredCollar>>();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : r.device.platformName;
        if (!CollarBleProtocol.isLikelyCollarName(name) &&
            name.trim().isEmpty) {
          // Still allow unnamed devices that advertise our service UUID.
          final hasService = r.advertisementData.serviceUuids.any(
            (u) =>
                u.str.toLowerCase() ==
                CollarBleProtocol.serviceUuid.toLowerCase(),
          );
          if (!hasService) continue;
        } else if (!CollarBleProtocol.isLikelyCollarName(name) &&
            name.trim().isNotEmpty) {
          // Show other named ESP32-like devices; skip unrelated phones/watches
          // unless name looks collar-related.
          if (!name.toUpperCase().contains('ESP32') &&
              !name.toUpperCase().contains('HAVAPAW') &&
              !name.toUpperCase().contains('COLLAR')) {
            continue;
          }
        }

        final displayName =
            name.trim().isEmpty ? 'ESP32 (${r.device.remoteId})' : name.trim();
        _found[r.device.remoteId.str] = DiscoveredCollar(
          remoteId: r.device.remoteId.str,
          name: displayName,
          rssi: r.rssi,
          device: r.device,
        );
      }
      if (!controller.isClosed) {
        final list = _found.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        controller.add(list);
      }
    });

    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );

    // Yield current list as a broadcast-like stream via controller.
    yield* controller.stream;

    await Future<void>.delayed(timeout);
    await stopScan();
    if (!controller.isClosed) await controller.close();
  }

  /// One-shot helper: scan for [timeout] and return whatever was found.
  static Future<List<DiscoveredCollar>> scanOnce({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await stopScan();
    _found.clear();

    if (!await FlutterBluePlus.isSupported) {
      throw StateError('bluetooth_not_available');
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {
        throw StateError('bluetooth_off');
      }
    }

    if (!await ensurePermissions()) {
      throw StateError('bluetooth_permissions_required');
    }

    final completer = Completer<List<DiscoveredCollar>>();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : r.device.platformName;
        final hasService = r.advertisementData.serviceUuids.any(
          (u) =>
              u.str.toLowerCase() ==
              CollarBleProtocol.serviceUuid.toLowerCase(),
        );
        final likely = CollarBleProtocol.isLikelyCollarName(name) ||
            hasService ||
            name.toUpperCase().contains('COLLAR');
        if (!likely) continue;

        final displayName =
            name.trim().isEmpty ? 'ESP32 (${r.device.remoteId})' : name.trim();
        _found[r.device.remoteId.str] = DiscoveredCollar(
          remoteId: r.device.remoteId.str,
          name: displayName,
          rssi: r.rssi,
          device: r.device,
        );
      }
    });

    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );

    await Future<void>.delayed(timeout);
    await stopScan();
    final list = _found.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    if (!completer.isCompleted) completer.complete(list);
    return list;
  }

  static Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
  }

  /// Connects over BLE, sends WiFi + Firestore binding, waits for status.
  /// Returns the device id to store on the pet as `collarId`.
  static Future<String> provisionAndBind({
    required DiscoveredCollar collar,
    required CollarProvisionPayload payload,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    await stopScan();
    final device = collar.device;

    try {
      await device.connect(timeout: timeout);
    } catch (e) {
      debugPrint('BLE connect failed: $e');
      throw StateError('connection_failed');
    }

    try {
      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) =>
            s.uuid.str.toLowerCase() ==
            CollarBleProtocol.serviceUuid.toLowerCase(),
        orElse: () => throw StateError('gatt_service_missing'),
      );

      final configChar = service.characteristics.firstWhere(
        (c) =>
            c.uuid.str.toLowerCase() ==
            CollarBleProtocol.configCharUuid.toLowerCase(),
        orElse: () => throw StateError('gatt_config_missing'),
      );

      BluetoothCharacteristic? statusChar;
      try {
        statusChar = service.characteristics.firstWhere(
          (c) =>
              c.uuid.str.toLowerCase() ==
              CollarBleProtocol.statusCharUuid.toLowerCase(),
        );
      } catch (_) {
        statusChar = null;
      }

      BluetoothCharacteristic? deviceIdChar;
      try {
        deviceIdChar = service.characteristics.firstWhere(
          (c) =>
              c.uuid.str.toLowerCase() ==
              CollarBleProtocol.deviceIdCharUuid.toLowerCase(),
        );
      } catch (_) {
        deviceIdChar = null;
      }

      String boundId = payload.deviceId;
      if (deviceIdChar != null) {
        try {
          final bytes = await deviceIdChar.read();
          final id = utf8.decode(bytes).trim();
          if (id.isNotEmpty) boundId = id;
        } catch (_) {}
      }

      final effectivePayload = CollarProvisionPayload(
        wifiSsid: payload.wifiSsid,
        wifiPassword: payload.wifiPassword,
        ownerUid: payload.ownerUid,
        petId: payload.petId,
        projectId: payload.projectId,
        apiKey: payload.apiKey,
        deviceId: boundId,
      );

      StreamSubscription<List<int>>? statusSub;
      final statusCompleter = Completer<String>();

      if (statusChar != null) {
        await statusChar.setNotifyValue(true);
        statusSub = statusChar.onValueReceived.listen((bytes) {
          final msg = utf8.decode(bytes, allowMalformed: true).trim();
          debugPrint('ESP32 status: $msg');
          if (msg.contains('FIREBASE_OK') || msg.contains('WIFI_OK')) {
            if (!statusCompleter.isCompleted) statusCompleter.complete(msg);
          } else if (msg.contains('WIFI_FAIL') ||
              msg.contains('FIREBASE_FAIL') ||
              msg.startsWith('ERROR')) {
            if (!statusCompleter.isCompleted) {
              statusCompleter.completeError(StateError(msg));
            }
          }
        });
      }

      final jsonBytes = utf8.encode(effectivePayload.toJsonString());
      // Chunk writes for BLE MTU limits (~180 bytes safe).
      const chunk = 160;
      for (var i = 0; i < jsonBytes.length; i += chunk) {
        final end =
            (i + chunk < jsonBytes.length) ? i + chunk : jsonBytes.length;
        await configChar.write(
          jsonBytes.sublist(i, end),
          withoutResponse: false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }

      if (statusChar != null) {
        try {
          await statusCompleter.future.timeout(timeout);
        } on TimeoutException {
          // Provision write succeeded; ESP32 may still connect to WiFi offline.
          debugPrint('Status timeout — binding anyway');
        } catch (e) {
          rethrow;
        } finally {
          await statusSub?.cancel();
        }
      } else {
        // No status characteristic — wait briefly then assume success.
        await Future<void>.delayed(const Duration(seconds: 3));
      }

      return boundId;
    } finally {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }
}
