/// Shared BLE GATT contract between the HavaPaw app and ESP32 collar firmware.
class CollarBleProtocol {
  /// Advertised BLE name prefix. Devices must start with this (or contain "ESP32").
  static const String namePrefix = 'HavaPaw-ESP32';

  /// Primary GATT service for WiFi provisioning + binding.
  static const String serviceUuid = '7b1e0001-5f8a-4b2c-9e3d-1a2b3c4d5e6f';

  /// Write UTF-8 JSON config:
  /// {ssid, pass, uid, petId, projectId, apiKey, deviceId}
  static const String configCharUuid = '7b1e0002-5f8a-4b2c-9e3d-1a2b3c4d5e6f';

  /// Notify UTF-8 status: READY | WIFI_OK | WIFI_FAIL | FIREBASE_OK | FIREBASE_FAIL | ERROR:...
  static const String statusCharUuid = '7b1e0003-5f8a-4b2c-9e3d-1a2b3c4d5e6f';

  /// Read-only device id string (e.g. HavaPaw-ESP32-A1B2).
  static const String deviceIdCharUuid = '7b1e0004-5f8a-4b2c-9e3d-1a2b3c4d5e6f';

  static bool isLikelyCollarName(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    final n = name.trim();
    return n.startsWith(namePrefix) || n.toUpperCase().contains('ESP32');
  }
}
