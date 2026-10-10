/*
 * HavaPaw collar - real sensor reading (MAX30102, MPU6050, DS18B20)
 *
 * WIRING (ESP32 Dev Module, all sensors on 3.3 V)
 *   MAX30102 and MPU6050 share one I2C bus:   SDA = GPIO21, SCL = GPIO22
 *   DS18B20 data pin:                         GPIO4  (4.7 kOhm pull-up to 3.3 V)
 *   Battery divider (optional):               GPIO34 (set BATTERY_ADC_PIN below)
 *
 * ARDUINO LIBRARIES (Library Manager)
 *   SparkFun MAX3010x Pulse and Proximity Sensor Library   (works for MAX30102)
 *   Adafruit MPU6050   (also installs Adafruit Unified Sensor and Adafruit BusIO)
 *   OneWire
 *   DallasTemperature
 *   ArduinoJson (6.x)  - already used by the sketch
 *
 * HOW IT WORKS
 *   One FreeRTOS task owns the I2C bus and runs every 20 ms (50 Hz):
 *     - reads the MPU6050 (acceleration in g) and counts steps
 *     - drains the MAX30102 FIFO and recomputes heart rate / SpO2 about once a second
 *     - starts / collects DS18B20 temperature conversions without blocking
 *   The main loop only calls sensorsSnapshot() when it is time to post.
 *
 * The pure signal-processing classes (StepDetector, StepWindow, MedianFilter) have no
 * hardware dependencies, so they can be tested on a PC (define HAVAPAW_HOST_TEST).
 */

#pragma once
#include <stdint.h>

// ============================== TUNING CONSTANTS ==============================
// Step detection from the neck accelerometer. Tune these on a real walk.
static const float    STEP_THRESHOLD_G       = 0.25f;  // |a| must exceed its slow average by this much
static const uint32_t MIN_STEP_INTERVAL_MS   = 250;    // ignore peaks closer than this (max ~4 steps/s)

// 'steps' sent to the app = steps in the last STEP_WINDOW_MIN minutes.
// The training data treats resting as ~20 and active as ~600 steps, which only makes
// sense for a window of several minutes, so the window is 5 minutes here.
// If you change this, regenerate the training data with matching step counts.
static const int      STEP_WINDOW_MIN        = 5;
static const uint32_t STEP_MIN_ELAPSED_MS    = 60000;  // do not report steps in the first minute after boot

// MAX30102 skin/fur contact and plausibility limits
static const uint32_t IR_CONTACT_THRESHOLD   = 50000;  // below this the sensor is not on skin
static const int      HR_MIN_BPM             = 40;
static const int      HR_MAX_BPM             = 250;
static const uint32_t VITALS_VALID_FOR_MS    = 10000;  // a result older than this counts as invalid

// DS18B20 measures collar/skin surface temperature, which reads LOWER than core body
// temperature. Calibrate once against a vet thermometer and put the difference here.
static const float    TEMP_OFFSET_C          = 0.0f;
static const float    TEMP_MIN_C             = 20.0f;
static const float    TEMP_MAX_C             = 45.0f;

// Optional battery monitor. -1 = not wired, the battery field is then not sent.
static const int      BATTERY_ADC_PIN        = -1;     // e.g. 34
static const float    BATTERY_DIVIDER_RATIO  = 2.0f;   // (R1+R2)/R2 of your divider
// ==============================================================================


// ------------------------------ pure logic ------------------------------------

// Median of the last 5 values: removes the occasional wild heart-rate result.
struct MedianFilter {
  int v[5];
  int n = 0;
  int head = 0;
  void clear() { n = 0; head = 0; }
  void add(int x) {
    v[head] = x;
    head = (head + 1) % 5;
    if (n < 5) n++;
  }
  int median() const {
    int tmp[5];
    for (int i = 0; i < n; i++) tmp[i] = v[i];
    for (int i = 1; i < n; i++) {           // insertion sort, n <= 5
      int key = tmp[i], j = i - 1;
      while (j >= 0 && tmp[j] > key) { tmp[j + 1] = tmp[j]; j--; }
      tmp[j + 1] = key;
    }
    return n == 0 ? 0 : tmp[n / 2];
  }
};

// Counts one step each time |a| rises STEP_THRESHOLD_G above its slow-moving average.
struct StepDetector {
  float baseline = 1.0f;     // slow average of |a| (about 1 g, gravity)
  bool  aboveThreshold = false;
  uint32_t lastStepMs = 0;
  bool  hasStepped = false;

  // magG = sqrt(ax^2 + ay^2 + az^2) in g. Returns true when a step is detected.
  bool update(float magG, uint32_t nowMs) {
    baseline += 0.02f * (magG - baseline);          // ~1 s time constant at 50 Hz
    float dev = magG - baseline;
    bool step = false;
    if (!aboveThreshold && dev >= STEP_THRESHOLD_G) {
      aboveThreshold = true;
      if (!hasStepped || (uint32_t)(nowMs - lastStepMs) >= MIN_STEP_INTERVAL_MS) {
        step = true;
        lastStepMs = nowMs;
        hasStepped = true;
      }
    } else if (aboveThreshold && dev < STEP_THRESHOLD_G * 0.5f) {
      aboveThreshold = false;                       // hysteresis: re-arm only after it falls back
    }
    return step;
  }
};

// Rolling count of steps over the last STEP_WINDOW_MIN one-minute bins (so the window
// is between STEP_WINDOW_MIN-1 and STEP_WINDOW_MIN minutes long, because the current
// minute is only partly filled).
struct StepWindow {
  static const int BINS = 16;                       // supports windows up to 16 minutes
  static const uint32_t BIN_MS = 60000;
  uint32_t bins[BINS] = {0};
  int idx = 0;
  uint32_t binStartMs = 0;
  uint32_t startMs = 0;
  bool started = false;

  void begin(uint32_t nowMs) { startMs = binStartMs = nowMs; started = true; }

  void advance(uint32_t nowMs) {
    if (!started) begin(nowMs);
    int guard = 0;
    while ((uint32_t)(nowMs - binStartMs) >= BIN_MS && guard++ < BINS) {
      idx = (idx + 1) % BINS;
      bins[idx] = 0;
      binStartMs += BIN_MS;
    }
    if ((uint32_t)(nowMs - binStartMs) >= BIN_MS) binStartMs = nowMs;   // very long gap
  }

  void add(uint32_t nowMs, uint32_t n) { advance(nowMs); bins[idx] += n; }

  uint32_t elapsedMs(uint32_t nowMs) const { return nowMs - startMs; }

  // Steps in the window. Until a full window has elapsed, the count is scaled up
  // proportionally so early readings are comparable with later ones.
  uint32_t total(uint32_t nowMs) {
    advance(nowMs);
    uint32_t sum = 0;
    for (int i = 0; i < STEP_WINDOW_MIN; i++) sum += bins[(idx - i + BINS) % BINS];
    uint32_t windowMs = (uint32_t)STEP_WINDOW_MIN * BIN_MS;
    uint32_t el = elapsedMs(nowMs);
    if (el > 0 && el < windowMs) return (uint32_t)((float)sum * (float)windowMs / (float)el + 0.5f);
    return sum;
  }
};


// --------------------------- hardware (ESP32 only) ----------------------------
#ifndef HAVAPAW_HOST_TEST

#include <Arduino.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include <Wire.h>
#include <math.h>
#include <string.h>
#include "MAX30105.h"          // SparkFun library; the class also drives the MAX30102
#include "spo2_algorithm.h"
#include <Adafruit_MPU6050.h>
#include <OneWire.h>
#include <DallasTemperature.h>

#define PIN_I2C_SDA 21
#define PIN_I2C_SCL 22
#define PIN_DS18B20 4

#define SENSOR_DEBUG_PRINT 1   // 1 = print one line every 2 s to the Serial Monitor

struct SensorSnapshot {
  bool     mpuOk = false;
  float    ax = 0, ay = 0, az = 0;      // g, latest sample
  bool     hrValid = false;
  int      heartRate = 0;               // bpm
  bool     spo2Valid = false;
  float    spo2 = 0;                    // %
  bool     tempValid = false;
  float    tempC = 0;                   // degC (offset applied)
  bool     stepsValid = false;
  uint32_t steps = 0;                   // steps in the last STEP_WINDOW_MIN minutes
  int      batteryPct = -1;             // -1 = unknown
  uint32_t irLevel = 0;                 // for debugging contact quality
};

static MAX30105 g_ppg;
static Adafruit_MPU6050 g_mpu;
static OneWire g_oneWire(PIN_DS18B20);
static DallasTemperature g_ds18(&g_oneWire);

static bool g_ppgOk = false, g_mpuOk = false, g_dsOk = false;
static SemaphoreHandle_t g_mutex = nullptr;
static SensorSnapshot g_snap;

// ---- state used only by the sensor task ----
static uint32_t g_irBuf[100], g_redBuf[100];
static int g_bufFill = 0;              // samples currently held (0..100)
static int g_newSinceCalc = 0;
static MedianFilter g_hrMedian;
static uint32_t g_lastHrOkMs = 0, g_lastSpo2OkMs = 0;
static int g_lastHr = 0;
static float g_lastSpo2 = 0;
static uint32_t g_irNow = 0;

static StepDetector g_stepDet;
static StepWindow g_stepWin;

static bool g_dsConverting = false;
static uint32_t g_dsRequestMs = 0, g_lastTempOkMs = 0;
static float g_lastTemp = 0;

static void ppgReset() {
  g_bufFill = 0;
  g_newSinceCalc = 0;
  g_hrMedian.clear();
}

static void ppgService(uint32_t nowMs) {
  g_ppg.check();                                    // pull new samples from the sensor FIFO
  while (g_ppg.available()) {
    uint32_t red = g_ppg.getFIFORed();
    uint32_t ir = g_ppg.getFIFOIR();
    g_ppg.nextSample();
    g_irNow = ir;

    if (ir < IR_CONTACT_THRESHOLD) {                // not on skin: discard everything collected
      ppgReset();
      continue;
    }
    if (g_bufFill < 100) {
      g_redBuf[g_bufFill] = red;
      g_irBuf[g_bufFill] = ir;
      g_bufFill++;
    } else {                                        // slide the 4 s window by one sample
      memmove(g_redBuf, g_redBuf + 1, 99 * sizeof(uint32_t));
      memmove(g_irBuf, g_irBuf + 1, 99 * sizeof(uint32_t));
      g_redBuf[99] = red;
      g_irBuf[99] = ir;
    }
    g_newSinceCalc++;

    // Recompute once per second (25 new samples at 25 samples/s) when the window is full
    if (g_bufFill == 100 && g_newSinceCalc >= 25) {
      g_newSinceCalc = 0;
      int32_t spo2 = 0, hr = 0;
      int8_t spo2Ok = 0, hrOk = 0;
      maxim_heart_rate_and_oxygen_saturation(g_irBuf, 100, g_redBuf, &spo2, &spo2Ok, &hr, &hrOk);
      if (hrOk && hr >= HR_MIN_BPM && hr <= HR_MAX_BPM) {
        g_hrMedian.add((int)hr);
        g_lastHr = g_hrMedian.median();
        g_lastHrOkMs = nowMs;
      }
      if (spo2Ok && spo2 >= 70 && spo2 <= 100) {
        g_lastSpo2 = (float)spo2;
        g_lastSpo2OkMs = nowMs;
      }
    }
  }
}

static void tempService(uint32_t nowMs) {
  if (!g_dsOk) return;
  if (!g_dsConverting && (nowMs - g_dsRequestMs >= 5000 || g_dsRequestMs == 0)) {
    g_ds18.requestTemperatures();                   // non-blocking (setWaitForConversion(false))
    g_dsRequestMs = nowMs;
    g_dsConverting = true;
  } else if (g_dsConverting && nowMs - g_dsRequestMs >= 800) {   // 12-bit conversion takes ~750 ms
    float t = g_ds18.getTempCByIndex(0);
    g_dsConverting = false;
    if (t != DEVICE_DISCONNECTED_C && t >= TEMP_MIN_C && t <= TEMP_MAX_C) {
      g_lastTemp = t + TEMP_OFFSET_C;
      g_lastTempOkMs = nowMs;
    }
  }
}

static int readBatteryPct() {
  if (BATTERY_ADC_PIN < 0) return -1;
  float v = analogReadMilliVolts(BATTERY_ADC_PIN) * BATTERY_DIVIDER_RATIO / 1000.0f;
  // Simple linear LiPo estimate (3.3 V empty .. 4.2 V full). The real curve is not linear.
  int pct = (int)((v - 3.3f) / (4.2f - 3.3f) * 100.0f + 0.5f);
  return pct < 0 ? 0 : (pct > 100 ? 100 : pct);
}

static void sensorTask(void *) {
  uint32_t lastDebugMs = 0;
  TickType_t lastWake = xTaskGetTickCount();
  for (;;) {
    uint32_t now = millis();
    SensorSnapshot s;                               // build locally, publish under the mutex

    if (g_mpuOk) {
      sensors_event_t a, g, t;
      g_mpu.getEvent(&a, &g, &t);                   // m/s^2
      const float G = 9.80665f;
      s.ax = a.acceleration.x / G;
      s.ay = a.acceleration.y / G;
      s.az = a.acceleration.z / G;
      s.mpuOk = true;
      float mag = sqrtf(s.ax * s.ax + s.ay * s.ay + s.az * s.az);
      if (g_stepDet.update(mag, now)) g_stepWin.add(now, 1);
    }

    if (g_ppgOk) ppgService(now);
    tempService(now);

    s.hrValid = g_lastHrOkMs != 0 && (now - g_lastHrOkMs) < VITALS_VALID_FOR_MS;
    s.heartRate = g_lastHr;
    s.spo2Valid = g_lastSpo2OkMs != 0 && (now - g_lastSpo2OkMs) < VITALS_VALID_FOR_MS;
    s.spo2 = g_lastSpo2;
    s.tempValid = g_lastTempOkMs != 0 && (now - g_lastTempOkMs) < 3 * 5000UL;
    s.tempC = g_lastTemp;
    s.stepsValid = g_mpuOk && g_stepWin.elapsedMs(now) >= STEP_MIN_ELAPSED_MS;
    s.steps = g_stepWin.total(now);
    s.batteryPct = readBatteryPct();
    s.irLevel = g_irNow;

    xSemaphoreTake(g_mutex, portMAX_DELAY);
    g_snap = s;
    xSemaphoreGive(g_mutex);

#if SENSOR_DEBUG_PRINT
    if (now - lastDebugMs >= 2000) {
      lastDebugMs = now;
      float m2 = s.ax * s.ax + s.ay * s.ay + s.az * s.az;
      Serial.printf("[SENS] HR=%s%d SpO2=%s%.0f T=%s%.2f IR=%lu |a|^2=%.3f steps=%lu%s\n",
                    s.hrValid ? "" : "(x)", s.heartRate,
                    s.spo2Valid ? "" : "(x)", s.spo2,
                    s.tempValid ? "" : "(x)", s.tempC,
                    (unsigned long)s.irLevel, m2,
                    (unsigned long)s.steps, s.stepsValid ? "" : " (warming up)");
    }
#endif
    vTaskDelayUntil(&lastWake, pdMS_TO_TICKS(20));  // 50 Hz
  }
}

// Call once from setup(). Sensors that are missing are skipped; the rest keep working.
static void sensorsBegin() {
  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  Wire.setClock(400000);

  g_mpuOk = g_mpu.begin();
  if (g_mpuOk) {
    g_mpu.setAccelerometerRange(MPU6050_RANGE_4_G);  // +/-4 g, same range as the public datasets
    g_mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
  }
  Serial.println(g_mpuOk ? "MPU6050 OK" : "MPU6050 NOT FOUND (check SDA/SCL wiring)");

  g_ppgOk = g_ppg.begin(Wire, I2C_SPEED_FAST);
  if (g_ppgOk) {
    // 100 samples/s averaged by 4 = 25 samples/s, which is what the SpO2 algorithm assumes
    g_ppg.setup(60 /*LED brightness*/, 4 /*average*/, 2 /*red+IR*/, 100 /*sps*/, 411 /*pulse width*/, 4096 /*ADC range*/);
  }
  Serial.println(g_ppgOk ? "MAX30102 OK" : "MAX30102 NOT FOUND (check SDA/SCL wiring)");

  g_ds18.begin();
  g_dsOk = g_ds18.getDeviceCount() > 0;
  if (g_dsOk) g_ds18.setWaitForConversion(false);
  Serial.println(g_dsOk ? "DS18B20 OK" : "DS18B20 NOT FOUND (check pin 4 and the 4.7k pull-up)");

  if (BATTERY_ADC_PIN >= 0) analogReadResolution(12);

  g_mutex = xSemaphoreCreateMutex();
  g_stepWin.begin(millis());
  xTaskCreatePinnedToCore(sensorTask, "sensors", 6144, nullptr, 2, nullptr, 1);
}

static SensorSnapshot sensorsSnapshot() {
  SensorSnapshot s;
  xSemaphoreTake(g_mutex, portMAX_DELAY);
  s = g_snap;
  xSemaphoreGive(g_mutex);
  return s;
}

#endif  // HAVAPAW_HOST_TEST
