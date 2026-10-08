/*
  HavaPaw - Phase 1.3: Duty-Cycle Sleep + Battery Monitoring + Firebase Upload
  -----------------------------------------------------------------------------
  Each wake cycle:
    1. Read battery level
    2. Listen to GPS for a short window
    3. Read MAX30102, MPU6050, DS18B20
    4. Connect to WiFi + Firebase Realtime Database, upload readings
    5. Turn WiFi off and go back to deep sleep

  Required libraries (Library Manager):
    - SparkFun MAX3010x Pulse and Proximity Sensor Library
    - Adafruit MPU6050 (+ Adafruit Unified Sensor, Adafruit BusIO)
    - OneWire
    - DallasTemperature
    - TinyGPSPlus
    - Firebase Arduino Client Library for ESP8266 and ESP32 (by Mobizt)

  Notes:
    - Deep sleep restarts the chip every cycle: setup() runs fresh, loop() is unused.
    - WiFi + Firebase sign-in is the most power-hungry step (several seconds).
      Raise UPLOAD_EVERY_N_WAKES to upload less often and save battery.
    - GPS rarely gets a fix inside a short window. The last known good position
      is kept in RTC memory and re-sent (flagged as stale) when there is no fresh fix.
*/

#include <Wire.h>
#include <WiFi.h>
#include <HardwareSerial.h>
#include "MAX30105.h"
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <TinyGPSPlus.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include "secrets.h"

// ---- Pin Definitions ----
#define ONE_WIRE_BUS     4
#define GPS_RX_PIN       16
#define GPS_TX_PIN       17
#define BATTERY_ADC_PIN  34   // ADC1 pin - safe to use while WiFi is on

// ---- Config ----
#define SLEEP_DURATION_SEC      30
#define UPLOAD_EVERY_N_WAKES    1      // 1 = upload every wake; 4 = every 4th wake, etc.
#define LOW_BATTERY_THRESHOLD   15.0   // percent
#define DIVIDER_RATIO           0.5    // R2 / (R1 + R2)
#define GPS_READ_WINDOW_MS      1000
#define WIFI_TIMEOUT_MS         15000
#define FIREBASE_TIMEOUT_MS     10000
#define KEEP_HISTORY            true   // also push each reading to /history

// ---- Objects ----
MAX30105 maxSensor;
Adafruit_MPU6050 mpu;
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature tempSensor(&oneWire);
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// ---- Survive deep sleep ----
RTC_DATA_ATTR int    bootCount = 0;
RTC_DATA_ATTR bool   hasLastFix = false;
RTC_DATA_ATTR double lastLat = 0;
RTC_DATA_ATTR double lastLng = 0;

// ---- Reading container ----
struct CollarReading {
  long   ir = 0, red = 0;
  float  ax = 0, ay = 0, az = 0;
  float  tempC = NAN;
  bool   gpsFresh = false;   // true = fix obtained this wake
  bool   gpsHasPos = false;  // true = lat/lng available (fresh or last known)
  double lat = 0, lng = 0;
  float  battery = 0;
  bool   maxOk = false, mpuOk = false;
};

// ============================================================
//  Battery
// ============================================================
float readBatteryPercent() {
  // Average a few samples to reduce ADC noise
  uint32_t sum = 0;
  for (int i = 0; i < 16; i++) {
    sum += analogRead(BATTERY_ADC_PIN);
    delay(2);
  }
  float raw = sum / 16.0;
  float adcVoltage = (raw / 4095.0) * 3.3;
  float batteryVoltage = adcVoltage / DIVIDER_RATIO;

  // Simple linear approximation: 3.0V = 0%, 4.2V = 100%
  float percent = (batteryVoltage - 3.0) / (4.2 - 3.0) * 100.0;
  return constrain(percent, 0, 100);
}

// ============================================================
//  Sensors
// ============================================================
void initSensors(CollarReading &r) {
  Wire.begin(21, 22);

  r.maxOk = maxSensor.begin(Wire, I2C_SPEED_FAST);
  if (r.maxOk) {
    maxSensor.setup();
  } else {
    Serial.println("[ERROR] MAX30102 not found.");
  }

  r.mpuOk = mpu.begin();
  if (r.mpuOk) {
    mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
  } else {
    Serial.println("[ERROR] MPU6050 not found.");
  }

  tempSensor.begin();
  gpsSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);
}

void listenToGps() {
  unsigned long start = millis();
  while (millis() - start < GPS_READ_WINDOW_MS) {
    while (gpsSerial.available() > 0) {
      gps.encode(gpsSerial.read());
    }
  }
}

void readSensors(CollarReading &r) {
  if (r.maxOk) {
    r.ir  = maxSensor.getIR();
    r.red = maxSensor.getRed();
  }

  if (r.mpuOk) {
    sensors_event_t a, g, t;
    mpu.getEvent(&a, &g, &t);
    r.ax = a.acceleration.x;
    r.ay = a.acceleration.y;
    r.az = a.acceleration.z;
  }

  tempSensor.requestTemperatures();
  float t = tempSensor.getTempCByIndex(0);
  r.tempC = (t == DEVICE_DISCONNECTED_C) ? NAN : t;   // -127 means sensor missing

  if (gps.location.isValid()) {
    r.gpsFresh = true;
    r.gpsHasPos = true;
    r.lat = gps.location.lat();
    r.lng = gps.location.lng();
    hasLastFix = true;
    lastLat = r.lat;
    lastLng = r.lng;
  } else if (hasLastFix) {
    r.gpsHasPos = true;
    r.lat = lastLat;
    r.lng = lastLng;
  }
}

void printReading(const CollarReading &r) {
  Serial.printf("MAX30102 -> IR: %ld | Red: %ld\n", r.ir, r.red);
  Serial.printf("MPU6050  -> X:%.2f Y:%.2f Z:%.2f\n", r.ax, r.ay, r.az);
  if (isnan(r.tempC)) Serial.println("DS18B20  -> not connected");
  else                Serial.printf("DS18B20  -> %.2f C\n", r.tempC);
  if (r.gpsHasPos) {
    Serial.printf("NEO-6M   -> Lat: %.6f Lng: %.6f (%s)\n",
                  r.lat, r.lng, r.gpsFresh ? "fresh" : "last known");
  } else {
    Serial.println("NEO-6M   -> No GPS fix yet.");
  }
}

// ============================================================
//  WiFi + Firebase
// ============================================================
bool connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < WIFI_TIMEOUT_MS) {
    delay(250);
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("WiFi connected, IP: ");
    Serial.println(WiFi.localIP());
    return true;
  }
  Serial.println("[ERROR] WiFi connection timed out.");
  return false;
}

bool connectFirebase() {
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  unsigned long start = millis();
  while (!Firebase.ready() && millis() - start < FIREBASE_TIMEOUT_MS) {
    delay(200);
  }
  if (Firebase.ready()) return true;
  Serial.println("[ERROR] Firebase sign-in timed out.");
  return false;
}

bool uploadReading(const CollarReading &r) {
  FirebaseJson json;
  json.set("ir", (int)r.ir);
  json.set("red", (int)r.red);
  json.set("accelX", r.ax);
  json.set("accelY", r.ay);
  json.set("accelZ", r.az);
  json.set("battery", r.battery);
  json.set("lowBattery", r.battery < LOW_BATTERY_THRESHOLD);
  json.set("wake", bootCount);
  json.set("timestamp/.sv", "timestamp");   // server-side timestamp

  if (!isnan(r.tempC)) json.set("tempC", r.tempC);

  json.set("gpsFresh", r.gpsFresh);
  if (r.gpsHasPos) {
    json.set("lat", r.lat);
    json.set("lng", r.lng);
  }

  String base = String("/collars/") + COLLAR_ID;

  bool ok = Firebase.RTDB.setJSON(&fbdo, (base + "/latest").c_str(), &json);
  if (!ok) {
    Serial.print("[ERROR] Upload failed: ");
    Serial.println(fbdo.errorReason());
    return false;
  }

  if (KEEP_HISTORY) {
    if (!Firebase.RTDB.pushJSON(&fbdo, (base + "/history").c_str(), &json)) {
      Serial.print("[WARN] History push failed: ");
      Serial.println(fbdo.errorReason());
    }
  }
  return true;
}

// ============================================================
//  Main
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(200);

  bootCount++;
  Serial.println("=================================");
  Serial.printf("Wake #%d\n", bootCount);

  CollarReading reading;

  // 1. Battery first (before WiFi turns on and adds load)
  reading.battery = readBatteryPercent();
  Serial.printf("Battery: %.1f%%\n", reading.battery);
  if (reading.battery < LOW_BATTERY_THRESHOLD) {
    Serial.println("[WARNING] Battery low - flagged in upload (lowBattery = true).");
  }

  // 2. Sensors + GPS
  initSensors(reading);
  listenToGps();
  readSensors(reading);
  printReading(reading);

  // 3. Upload (every Nth wake; always upload when battery is low)
  bool shouldUpload = (bootCount % UPLOAD_EVERY_N_WAKES == 0) ||
                      (reading.battery < LOW_BATTERY_THRESHOLD);

  if (shouldUpload) {
    if (connectWiFi() && connectFirebase()) {
      Serial.println(uploadReading(reading) ? "Uploaded to Firebase." : "Upload failed.");
    } else {
      Serial.println("Skipping upload this cycle.");
    }
    WiFi.disconnect(true);
    WiFi.mode(WIFI_OFF);
  } else {
    Serial.println("Upload skipped this wake (duty cycle).");
  }

  // 4. Sleep
  Serial.printf("Sleeping for %d seconds...\n", SLEEP_DURATION_SEC);
  Serial.flush();
  esp_sleep_enable_timer_wakeup((uint64_t)SLEEP_DURATION_SEC * 1000000ULL);
  esp_deep_sleep_start();
}

void loop() {
  // Not used - deep sleep restarts from setup() every cycle
}
