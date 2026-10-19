/*
 * HavaPaw ESP32 Smart Collar firmware
 *
 * Flow:
 *  1) Advertises as HavaPaw-ESP32-XXXX over BLE
 *  2) App writes a JSON config {ssid, pass, url, token, deviceId} to the Config characteristic
 *     (and registers the token in Firestore: deviceTokens/{deviceId})
 *  3) ESP32 joins Wi-Fi and POSTs a reading every 30 s to the ingestCollarData Cloud Function,
 *     sending the secret token in the X-Device-Token header. The function writes
 *     users/{uid}/collarData/{autoId}; no Firestore credentials are stored on the collar.
 *
 * Sensors (see havapaw_sensors.h for wiring and tuning constants):
 *   MAX30102 -> heart rate + SpO2, MPU6050 -> acceleration + steps, DS18B20 -> temperature,
 *   NEO-6M   -> GPS (RX2 = GPIO16 <- GPS TX, TX2 = GPIO17 -> GPS RX)
 *
 * Power: the sensor task must run continuously (heart rate needs a steady PPG stream and the
 * step counter uses a 5-minute window), so deep sleep is not used. Instead the CPU runs at
 * 80 MHz, Wi-Fi modem sleep is on, uploads are 30 s apart and BLE advertising stops after
 * pairing. Set BATTERY_ADC_PIN in havapaw_sensors.h to enable battery reporting and the
 * low-battery push notification.
 *
 * Arduino IDE boards: ESP32 Dev Module
 * Libraries: ArduinoJson 6.x (Benoit Blanchon), SparkFun MAX3010x, Adafruit MPU6050,
 *            OneWire, DallasTemperature, TinyGPSPlus
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <TinyGPSPlus.h>   // Library Manager: "TinyGPSPlus" by Mikal Hart
#include <ArduinoJson.h>
#include <Preferences.h>
#include "havapaw_sensors.h"

// Must match havapaw/lib/services/collar_ble_protocol.dart
#define SERVICE_UUID        "7b1e0001-5f8a-4b2c-9e3d-1a2b3c4d5e6f"
#define CONFIG_CHAR_UUID    "7b1e0002-5f8a-4b2c-9e3d-1a2b3c4d5e6f"
#define STATUS_CHAR_UUID    "7b1e0003-5f8a-4b2c-9e3d-1a2b3c4d5e6f"
#define DEVICE_ID_CHAR_UUID "7b1e0004-5f8a-4b2c-9e3d-1a2b3c4d5e6f"

// ---- TLS -------------------------------------------------------------------
// Root certificates the ingest endpoint (*.cloudfunctions.net) chains to.
// The collar only talks to a server whose certificate is signed by one of these,
// so the device token cannot be captured by a fake Wi-Fi access point or proxy.
// Both roots are valid until 2036. Certificate dates are checked, so the clock
// must be set by NTP before the first upload.
static const char GOOGLE_ROOT_CAS[] =
// GTS Root R1
"-----BEGIN CERTIFICATE-----\n"
"MIIFVzCCAz+gAwIBAgINAgPlk28xsBNJiGuiFzANBgkqhkiG9w0BAQwFADBHMQsw\n"
"CQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEU\n"
"MBIGA1UEAxMLR1RTIFJvb3QgUjEwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAw\n"
"MDAwWjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZp\n"
"Y2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjEwggIiMA0GCSqGSIb3DQEBAQUA\n"
"A4ICDwAwggIKAoICAQC2EQKLHuOhd5s73L+UPreVp0A8of2C+X0yBoJx9vaMf/vo\n"
"27xqLpeXo4xL+Sv2sfnOhB2x+cWX3u+58qPpvBKJXqeqUqv4IyfLpLGcY9vXmX7w\n"
"Cl7raKb0xlpHDU0QM+NOsROjyBhsS+z8CZDfnWQpJSMHobTSPS5g4M/SCYe7zUjw\n"
"TcLCeoiKu7rPWRnWr4+wB7CeMfGCwcDfLqZtbBkOtdh+JhpFAz2weaSUKK0Pfybl\n"
"qAj+lug8aJRT7oM6iCsVlgmy4HqMLnXWnOunVmSPlk9orj2XwoSPwLxAwAtcvfaH\n"
"szVsrBhQf4TgTM2S0yDpM7xSma8ytSmzJSq0SPly4cpk9+aCEI3oncKKiPo4Zor8\n"
"Y/kB+Xj9e1x3+naH+uzfsQ55lVe0vSbv1gHR6xYKu44LtcXFilWr06zqkUspzBmk\n"
"MiVOKvFlRNACzqrOSbTqn3yDsEB750Orp2yjj32JgfpMpf/VjsPOS+C12LOORc92\n"
"wO1AK/1TD7Cn1TsNsYqiA94xrcx36m97PtbfkSIS5r762DL8EGMUUXLeXdYWk70p\n"
"aDPvOmbsB4om3xPXV2V4J95eSRQAogB/mqghtqmxlbCluQ0WEdrHbEg8QOB+DVrN\n"
"VjzRlwW5y0vtOUucxD/SVRNuJLDWcfr0wbrM7Rv1/oFB2ACYPTrIrnqYNxgFlQID\n"
"AQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E\n"
"FgQU5K8rJnEaK0gnhS9SZizv8IkTcT4wDQYJKoZIhvcNAQEMBQADggIBAJ+qQibb\n"
"C5u+/x6Wki4+omVKapi6Ist9wTrYggoGxval3sBOh2Z5ofmmWJyq+bXmYOfg6LEe\n"
"QkEzCzc9zolwFcq1JKjPa7XSQCGYzyI0zzvFIoTgxQ6KfF2I5DUkzps+GlQebtuy\n"
"h6f88/qBVRRiClmpIgUxPoLW7ttXNLwzldMXG+gnoot7TiYaelpkttGsN/H9oPM4\n"
"7HLwEXWdyzRSjeZ2axfG34arJ45JK3VmgRAhpuo+9K4l/3wV3s6MJT/KYnAK9y8J\n"
"ZgfIPxz88NtFMN9iiMG1D53Dn0reWVlHxYciNuaCp+0KueIHoI17eko8cdLiA6Ef\n"
"MgfdG+RCzgwARWGAtQsgWSl4vflVy2PFPEz0tv/bal8xa5meLMFrUKTX5hgUvYU/\n"
"Z6tGn6D/Qqc6f1zLXbBwHSs09dR2CQzreExZBfMzQsNhFRAbd03OIozUhfJFfbdT\n"
"6u9AWpQKXCBfTkBdYiJ23//OYb2MI3jSNwLgjt7RETeJ9r/tSQdirpLsQBqvFAnZ\n"
"0E6yove+7u7Y/9waLd64NnHi/Hm3lCXRSHNboTXns5lndcEZOitHTtNCjv0xyBZm\n"
"2tIMPNuzjsmhDYAPexZ3FL//2wmUspO8IFgV6dtxQ/PeEMMA3KgqlbbC1j+Qa3bb\n"
"bP6MvPJwNQzcmRk13NfIRmPVNnGuV/u3gm3c\n"
"-----END CERTIFICATE-----\n"
// GTS Root R4
"-----BEGIN CERTIFICATE-----\n"
"MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD\n"
"VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG\n"
"A1UEAxMLR1RTIFJvb3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw\n"
"WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz\n"
"IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNi\n"
"AATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvVYRg1rkDdc/eJkTBa6zzuhXyi\n"
"QHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHci8nHc8iMai/lxKvR\n"
"HYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW\n"
"BBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D\n"
"9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8\n"
"p/SgguMh1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD\n"
"-----END CERTIFICATE-----\n";

// ---- GPS (NEO-6M) ----------------------------------------------------------
#define GPS_RX_PIN 16          // ESP32 RX2  <- GPS TX
#define GPS_TX_PIN 17          // ESP32 TX2  -> GPS RX
#define GPS_MAX_AGE_MS 120000  // a position older than this is not sent
HardwareSerial gpsSerial(2);
TinyGPSPlus gps;
double lastLat = 0, lastLng = 0;
uint32_t lastFixMs = 0;
bool haveFix = false;

// Power: BLE stops advertising this long after boot once the collar is provisioned
// (power-cycle the collar to pair it again).
const unsigned long BLE_ADVERTISE_WINDOW_MS = 120000;
bool bleAdvertisingStopped = false;

Preferences prefs;
BLECharacteristic *statusChar = nullptr;
BLECharacteristic *deviceIdChar = nullptr;

String deviceId;
String wifiSsid;
String wifiPass;
String ingestUrl;   // https://<region>-<project>.cloudfunctions.net/ingestCollarData
String deviceToken; // 64-hex secret registered by the app in deviceTokens/{deviceId}

String configBuffer;
bool provisionPending = false;
unsigned long lastPostMs = 0;
const unsigned long POST_INTERVAL_MS = 30000;   // one upload every 30 s (proposal duty cycle)

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
  if (ingestUrl.isEmpty() || deviceToken.length() != 64) {
    notifyStatus("ERROR:missing_config");
    return false;
  }

  // Wait briefly for NTP after WiFi: timestamps need it, and so does certificate checking
  for (int i = 0; i < 20 && time(nullptr) < 100000; i++) {
    delay(250);
  }
  if (time(nullptr) < 100000) {
    // Not a failure: the clock is usually set within a few seconds; try at the next upload.
    notifyStatus("TIME_WAIT");
    return false;
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

  StaticJsonDocument<768> doc;
  doc["deviceId"] = deviceId;

  time_t now = time(nullptr);
  if (now > 100000) {
    char iso[32];
    strftime(iso, sizeof(iso), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
    doc["timestamp"] = iso;   // server falls back to its own clock if this is missing or far off
  }

  doc["heartRate"] = s.heartRate;
  doc["temperature"] = roundf(s.tempC * 100.0f) / 100.0f;
  if (s.spo2Valid) doc["bloodOxygen"] = roundf(s.spo2);
  if (s.stepsValid) doc["steps"] = (int)s.steps;
  if (s.mpuOk) {
    // Latest single accelerometer sample in g; the app computes x^2+y^2+z^2 from it
    doc["accelerometerX"] = roundf(s.ax * 1000.0f) / 1000.0f;
    doc["accelerometerY"] = roundf(s.ay * 1000.0f) / 1000.0f;
    doc["accelerometerZ"] = roundf(s.az * 1000.0f) / 1000.0f;
  }
  if (s.batteryPct >= 0) doc["batteryLevel"] = s.batteryPct;

  // Last good GPS position (not older than GPS_MAX_AGE_MS). Without a fix the app
  // simply keeps showing the previous location.
  if (haveFix && (millis() - lastFixMs) < GPS_MAX_AGE_MS) {
    doc["latitude"] = lastLat;
    doc["longitude"] = lastLng;
  }

  String body;
  serializeJson(doc, body);

  // TLS with the server certificate checked against Google's root CAs (see GOOGLE_ROOT_CAS).
  WiFiClientSecure client;
  client.setCACert(GOOGLE_ROOT_CAS);
  HTTPClient http;
  http.begin(client, ingestUrl);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Token", deviceToken);
  int code = http.POST(body);
  String resp = http.getString();
  http.end();

  Serial.printf("Ingest POST %d: %s\n", code, resp.c_str());
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
  ingestUrl = doc["url"] | "";
  deviceToken = doc["token"] | "";
  String incomingId = doc["deviceId"] | "";
  if (incomingId.length() > 0) deviceId = incomingId;

  prefs.begin("havapaw", false);
  prefs.putString("ssid", wifiSsid);
  prefs.putString("pass", wifiPass);
  prefs.putString("url", ingestUrl);
  prefs.putString("token", deviceToken);
  prefs.putString("deviceId", deviceId);
  prefs.end();

  if (deviceIdChar) deviceIdChar->setValue(deviceId.c_str());

  provisionPending = true;
}

class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    // .c_str() works whether getValue() returns std::string (esp32 core 2.x) or String (3.x)
    String value = characteristic->getValue().c_str();
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
  ingestUrl = prefs.getString("url", "");
  deviceToken = prefs.getString("token", "");
  deviceId = prefs.getString("deviceId", "");
  prefs.end();
  if (deviceId.isEmpty()) deviceId = makeDeviceId();
}

void setup() {
  Serial.begin(115200);
  delay(500);
  setCpuFrequencyMhz(80);   // enough for BLE + Wi-Fi + the 50 Hz sensor task; saves power
  sensorsBegin();
  gpsSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
  loadSavedConfig();
  setupBle();
  notifyStatus("READY");

  // Optional: enable NTP for proper timestamps after WiFi connects
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");

  if (!wifiSsid.isEmpty()) {
    connectWifi();
  }
}

void updateGps() {
  while (gpsSerial.available() > 0) gps.encode(gpsSerial.read());
  if (gps.location.isValid() && gps.location.isUpdated()) {
    lastLat = gps.location.lat();
    lastLng = gps.location.lng();
    lastFixMs = millis();
    haveFix = true;
  }
}

void loop() {
  updateGps();

  // Once paired and online, stop advertising to save power (power-cycle to re-pair).
  if (!bleAdvertisingStopped && !deviceToken.isEmpty() && WiFi.status() == WL_CONNECTED &&
      millis() > BLE_ADVERTISE_WINDOW_MS) {
    BLEDevice::getAdvertising()->stop();
    bleAdvertisingStopped = true;
    Serial.println("BLE advertising stopped (provisioned)");
  }

  if (provisionPending) {
    bleAdvertisingStopped = false;
    provisionPending = false;
    if (connectWifi()) {
      // Try an immediate sync so the app can confirm FIREBASE_OK
      postCollarReading();
    }
  }

  if (WiFi.status() == WL_CONNECTED && !deviceToken.isEmpty() && millis() - lastPostMs > POST_INTERVAL_MS) {
    lastPostMs = millis();
    postCollarReading();
  }

  delay(20);
}
