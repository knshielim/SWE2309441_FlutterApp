/*
 * HavaPaw ESP32 Smart Collar firmware
 *
 * Flow:
 *  1) Advertises as HavaPaw-ESP32-XXXX over BLE
 *  2) App writes JSON config to the Config characteristic
 *  3) ESP32 joins WiFi and posts readings to Firestore REST
 *
 * Sensors (see havapaw_sensors.h for wiring and tuning constants):
 *   MAX30102 -> heart rate + SpO2, MPU6050 -> acceleration + steps, DS18B20 -> temperature
 *
 * Arduino IDE boards: ESP32 Dev Module
 * Libraries: ArduinoJson 6.x (Benoit Blanchon), SparkFun MAX3010x, Adafruit MPU6050,
 *            OneWire, DallasTemperature
 *
 * Firestore path written:
 *   users/{uid}/collarData/{autoId}
 *
 * Required Firestore rule example (school / demo — tighten for production):
 *   match /users/{userId}/collarData/{docId} {
 *     allow read, write: if request.auth != null && request.auth.uid == userId
 *                        || true; // temporarily allow device writes without auth
 *   }
 *
 * Better long-term: Cloud Function endpoint or Firebase Auth anonymous token.
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include "havapaw_sensors.h"

// Must match havapaw/lib/services/collar_ble_protocol.dart
#define SERVICE_UUID        "7b1e0001-5f8a-4b2c-9e3d-1a2b3c4d5e6f"
#define CONFIG_CHAR_UUID    "7b1e0002-5f8a-4b2c-9e3d-1a2b3c4d5e6f"
#define STATUS_CHAR_UUID    "7b1e0003-5f8a-4b2c-9e3d-1a2b3c4d5e6f"
#define DEVICE_ID_CHAR_UUID "7b1e0004-5f8a-4b2c-9e3d-1a2b3c4d5e6f"

Preferences prefs;
BLECharacteristic *statusChar = nullptr;
BLECharacteristic *deviceIdChar = nullptr;

String deviceId;
String wifiSsid;
String wifiPass;
String ownerUid;
String petId;
String projectId;
String apiKey;

String configBuffer;
bool provisionPending = false;
unsigned long lastPostMs = 0;
const unsigned long POST_INTERVAL_MS = 15000;

void notifyStatus(const String &msg) {
  Serial.println("[STATUS] " + msg);
  if (statusChar) {
    statusChar->setValue(msg.c_str());
    statusChar->notify();
  }
}

String makeDeviceId() {
  uint64_t mac = ESP.getEfuseMac();
  char buf[24];
  snprintf(buf, sizeof(buf), "HavaPaw-ESP32-%04X", (uint16_t)(mac & 0xFFFF));
  return String(buf);
}

bool connectWifi() {
  if (wifiSsid.isEmpty()) return false;
  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSsid.c_str(), wifiPass.c_str());
  Serial.printf("Connecting WiFi SSID=%s\n", wifiSsid.c_str());
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(250);
    Serial.print(".");
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println(WiFi.localIP());
    notifyStatus("WIFI_OK");
    return true;
  }
  notifyStatus("WIFI_FAIL");
  return false;
}

bool postCollarReading() {
  if (WiFi.status() != WL_CONNECTED) {
    if (!connectWifi()) return false;
  }
  if (ownerUid.isEmpty() || projectId.isEmpty() || apiKey.isEmpty()) {
    notifyStatus("ERROR:missing_firebase_config");
    return false;
  }

  // Wait briefly for NTP after WiFi so timestamps are valid ISO-8601
  for (int i = 0; i < 20 && time(nullptr) < 100000; i++) {
    delay(250);
  }

  // Real sensor readings (collected continuously by the sensor task in havapaw_sensors.h)
  SensorSnapshot s = sensorsSnapshot();
  if (!s.hrValid || !s.tempValid) {
    // Never post made-up or stale vitals: wait until the sensors have a good reading.
    // (Status text deliberately avoids FAIL/ERROR so the app does not treat it as a failure.)
    String missing = String(s.hrValid ? "" : " heart_rate") + String(s.tempValid ? "" : " temperature");
    notifyStatus("SENSOR_WAIT:" + missing);
    return false;
  }

  String url = "https://firestore.googleapis.com/v1/projects/" + projectId +
               "/databases/(default)/documents/users/" + ownerUid +
               "/collarData?key=" + apiKey;

  DynamicJsonDocument doc(2048);
  JsonObject fields = doc.createNestedObject("fields");

  auto setString = [&](const char *key, const String &val) {
    fields[key]["stringValue"] = val;
  };
  auto setInt = [&](const char *key, int val) {
    fields[key]["integerValue"] = String(val);
  };
  auto setDouble = [&](const char *key, double val) {
    fields[key]["doubleValue"] = val;
  };

  setString("deviceId", deviceId);
  setString("deviceName", deviceId);
  setString("petId", petId);

  time_t now = time(nullptr);
  char iso[40];
  if (now > 100000) {
    strftime(iso, sizeof(iso), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
  } else {
    // NTP not ready — still send a parseable stamp; app will tolerate it
    snprintf(iso, sizeof(iso), "2026-01-01T00:00:00Z");
  }
  setString("timestamp", String(iso));

  setInt("heartRate", s.heartRate);
  setDouble("temperature", roundf(s.tempC * 100.0f) / 100.0f);
  if (s.spo2Valid) setDouble("bloodOxygen", roundf(s.spo2));
  if (s.stepsValid) setInt("steps", (int)s.steps);
  if (s.mpuOk) {
    // Latest single accelerometer sample in g; the app computes x^2+y^2+z^2 from it
    setDouble("accelerometerX", roundf(s.ax * 1000.0f) / 1000.0f);
    setDouble("accelerometerY", roundf(s.ay * 1000.0f) / 1000.0f);
    setDouble("accelerometerZ", roundf(s.az * 1000.0f) / 1000.0f);
  }
  if (s.batteryPct >= 0) setInt("batteryLevel", s.batteryPct);

  String body;
  serializeJson(doc, body);

  HTTPClient http;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(body);
  String resp = http.getString();
  http.end();

  Serial.printf("Firestore POST %d: %s\n", code, resp.c_str());
  if (code >= 200 && code < 300) {
    notifyStatus("FIREBASE_OK");
    return true;
  }
  notifyStatus("FIREBASE_FAIL");
  return false;
}

void applyConfigJson(const String &json) {
  StaticJsonDocument<768> doc;
  DeserializationError err = deserializeJson(doc, json);
  if (err) {
    notifyStatus("ERROR:bad_json");
    return;
  }

  wifiSsid = doc["ssid"] | "";
  wifiPass = doc["pass"] | "";
  ownerUid = doc["uid"] | "";
  petId = doc["petId"] | "";
  projectId = doc["projectId"] | "";
  apiKey = doc["apiKey"] | "";
  String incomingId = doc["deviceId"] | "";
  if (incomingId.length() > 0) deviceId = incomingId;

  prefs.begin("havapaw", false);
  prefs.putString("ssid", wifiSsid);
  prefs.putString("pass", wifiPass);
  prefs.putString("uid", ownerUid);
  prefs.putString("petId", petId);
  prefs.putString("projectId", projectId);
  prefs.putString("apiKey", apiKey);
  prefs.putString("deviceId", deviceId);
  prefs.end();

  if (deviceIdChar) deviceIdChar->setValue(deviceId.c_str());

  provisionPending = true;
}

class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    String value = characteristic->getValue();
    if (value.length() == 0) return;
    configBuffer += value;
    // Complete JSON object received
    if (configBuffer.indexOf('{') >= 0 && configBuffer.lastIndexOf('}') > configBuffer.indexOf('{')) {
      String json = configBuffer.substring(configBuffer.indexOf('{'), configBuffer.lastIndexOf('}') + 1);
      configBuffer = "";
      applyConfigJson(json);
    }
  }
};

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    Serial.println("BLE client connected");
  }
  void onDisconnect(BLEServer *server) override {
    Serial.println("BLE client disconnected — restart advertising");
    delay(100);
    server->startAdvertising();
  }
};

void setupBle() {
  BLEDevice::init(deviceId.c_str());
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(SERVICE_UUID);

  BLECharacteristic *configChar = service->createCharacteristic(
      CONFIG_CHAR_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  configChar->setCallbacks(new ConfigCallbacks());

  statusChar = service->createCharacteristic(
      STATUS_CHAR_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  statusChar->addDescriptor(new BLE2902());
  statusChar->setValue("READY");

  deviceIdChar = service->createCharacteristic(
      DEVICE_ID_CHAR_UUID,
      BLECharacteristic::PROPERTY_READ);
  deviceIdChar->setValue(deviceId.c_str());

  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
  Serial.println("BLE advertising as " + deviceId);
}

void loadSavedConfig() {
  prefs.begin("havapaw", true);
  wifiSsid = prefs.getString("ssid", "");
  wifiPass = prefs.getString("pass", "");
  ownerUid = prefs.getString("uid", "");
  petId = prefs.getString("petId", "");
  projectId = prefs.getString("projectId", "");
  apiKey = prefs.getString("apiKey", "");
  deviceId = prefs.getString("deviceId", "");
  prefs.end();
  if (deviceId.isEmpty()) deviceId = makeDeviceId();
}

void setup() {
  Serial.begin(115200);
  delay(500);
  sensorsBegin();
  loadSavedConfig();
  setupBle();
  notifyStatus("READY");

  // Optional: enable NTP for proper timestamps after WiFi connects
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");

  if (!wifiSsid.isEmpty()) {
    connectWifi();
  }
}

void loop() {
  if (provisionPending) {
    provisionPending = false;
    if (connectWifi()) {
      // Try an immediate sync so the app can confirm FIREBASE_OK
      postCollarReading();
    }
  }

  if (WiFi.status() == WL_CONNECTED && !ownerUid.isEmpty() && millis() - lastPostMs > POST_INTERVAL_MS) {
    lastPostMs = millis();
    postCollarReading();
  }

  delay(50);
}
