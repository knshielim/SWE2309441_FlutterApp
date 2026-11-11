# HavaPaw: Complete Project Guide

**An IoT-Based Smart Pet Collar System with ML Health Prediction and LLM-Powered Mobile Guidance**

This guide explains the whole project: what each part does, how the parts talk to each other, where
every file lives, and why things were built the way they are. Read sections 1–3 first for the big
picture, then dip into the part you need.

---

## Contents

1. [What HavaPaw is](#1-what-havapaw-is)
2. [How the system fits together](#2-how-the-system-fits-together)
3. [Repository layout](#3-repository-layout)
4. [The collar (ESP32 firmware)](#4-the-collar-esp32-firmware)
5. [The backend (Firebase)](#5-the-backend-firebase)
6. [The mobile app (Flutter)](#6-the-mobile-app-flutter)
7. [Health logic: thresholds, baselines and alerts](#7-health-logic-thresholds-baselines-and-alerts)
8. [Machine learning pipeline](#8-machine-learning-pipeline)
9. [LLM features (GPT-4o)](#9-llm-features-gpt-4o)
10. [Developer tools: virtual collar and USB bridge](#10-developer-tools-virtual-collar-and-usb-bridge)
11. [Security and privacy](#11-security-and-privacy)
12. [Testing](#12-testing)
13. [How to run, build and deploy](#13-how-to-run-build-and-deploy)
14. [Known limitations (be honest about these)](#14-known-limitations)
15. [Likely viva questions and short answers](#15-likely-viva-questions)
16. [Glossary](#16-glossary)

---

## 1. What HavaPaw is

HavaPaw is a smart collar plus a phone app that helps owners look after a dog or cat.

- The **collar** (an ESP32 board with sensors) measures heart rate, blood oxygen, body temperature,
  movement and GPS position, and uploads a reading every **30 seconds**.
- The **backend** (Firebase) stores the readings, checks them against health rules and sends push
  alerts (high heart rate, fever, stress, leaving the safe zone, low battery, unusual change from the
  pet's normal).
- The **app** (Flutter, Android) shows live vitals, trends, a map with a safe zone, a health journal,
  and two "intelligent" features:
  - a **Random Forest** model (run on the phone as TensorFlow Lite) that classifies the pet's state as
    *resting, active, stressed* or *anomaly*;
  - a **Virtual Vet** powered by **GPT-4o** that turns the data into plain-language guidance.

The key idea is **personalisation**: every pet gets its own limits (based on species, size, age) and,
over time, its own learned resting heart-rate baseline.

---

## 2. How the system fits together

```
 ┌──────────────── COLLAR (ESP32) ────────────────┐
 │ MAX30102 (HR, SpO2)  MPU6050 (motion/steps)    │
 │ DS18B20 (temp)       NEO-6M (GPS)   battery    │
 └───────┬─────────────────────────────┬──────────┘
         │ 1. Bluetooth (setup only)    │ 2. Wi-Fi HTTPS POST every 30 s
         │    Wi-Fi + token sent        │    header X-Device-Token
         ▼                              ▼
 ┌──────────────┐            ┌──────────────────────────────┐
 │  Flutter app │            │ Cloud Function ingestCollarData│
 │  (phone)     │            │ checks token, validates values │
 └──────┬───────┘            └──────────────┬───────────────┘
        │ reads/writes (live)               │ writes users/{uid}/collarData/{id}
        ▼                                   ▼
 ┌──────────────────────── Cloud Firestore ────────────────────────┐
 │ users/{uid}/pets, collarData, alerts, geofences, journal, ...    │
 └──────────────┬───────────────────────────────────────────────────┘
                │ new reading triggers
                ▼
 ┌──────────────────────────────┐      ┌─────────────────────┐
 │ Cloud Function onCollarReading│────▶│ Firebase Cloud       │──▶ push to phone
 │ daily stats, alert rules,     │      │ Messaging (FCM)      │
 │ GPT-4o note for deviations    │      └─────────────────────┘
 └──────────────────────────────┘
   + generateVirtualVetAdvice (called by the app)   + dailyDigest (8 pm every day)
```

### The life of one reading

1. The collar reads its sensors and builds a JSON message, e.g.
   `{"deviceId":"HavaPaw-ESP32-1A2B","heartRate":88,"temperature":38.6,"steps":12,...}`.
2. It POSTs this over HTTPS to `ingestCollarData`, with its secret **device token** in the
   `X-Device-Token` header. The TLS certificate is pinned to Google's root CAs.
3. `ingestCollarData` looks up `deviceTokens/{deviceId}`, compares the token in constant time, checks
   the values are in sensible ranges, rate-limits (one reading per 4 s), and writes the reading to
   `users/{uid}/collarData/{newId}` with the owner's `petId`.
4. Writing that document **triggers** `onCollarReading`, which:
   - adds the reading to the pet's **daily summary** (`dailyStats/{date}`);
   - checks the **health rules** (needs 2 abnormal readings in a row, 15-minute cooldown);
   - checks the **baseline deviation** rule (≥ 35 % different from the pet's own 3-day normal) and asks
     GPT-4o to write a short note;
   - checks **battery** and **safe zone**;
   - saves each alert to `users/{uid}/alerts` and sends it as a push notification.
5. The app is listening to Firestore, so the new reading appears on screen within a second or two. The
   app also runs the TFLite model on it and shows explanations, check-ins, goals and so on.

---

## 3. Repository layout

```
SWE2309441_FlutterApp/
├── havapaw/                     Flutter app + Firebase backend
│   ├── lib/                     App source code (Dart)
│   │   ├── main.dart            Start-up: Firebase, language, routes
│   │   ├── firebase_options.dart  Generated Firebase config
│   │   ├── config/              Collar upload URL
│   │   ├── models/              Data classes and pure logic (testable, no Firebase)
│   │   ├── services/            Talk to Firebase, Bluetooth, ML, weather, PDF
│   │   ├── screens/             One file per screen
│   │   ├── widgets/             Reusable UI pieces
│   │   ├── theme/               Colours and text styles
│   │   └── utils/               Small helpers (default map view)
│   ├── assets/
│   │   ├── ml/                  pet_health_classifier.tflite + model_metadata.json
│   │   ├── translations/        en-US, ms-MY, id-ID, zh-CN JSON files
│   │   ├── audio/               Calming music + sound effects
│   │   └── images/              Logo
│   ├── functions/               Cloud Functions (Node.js 22)
│   │   ├── index.js             The 4 functions
│   │   ├── lib/rules.js         Pure alert/summary rules (unit tested)
│   │   └── test/rules.test.js   Tests for rules.js
│   ├── firestore.rules          Database security rules
│   ├── firebase.json            Firebase project config
│   ├── test/                    Flutter unit/widget tests
│   └── android/ ios/ web/ ...   Platform folders (Android is the target)
├── HavaPaw_Arduino/
│   ├── havapaw_collar/
│   │   ├── havapaw_collar.ino   The real collar firmware
│   │   └── havapaw_sensors.h    Sensor reading code
│   └── HavaPaw_Arduino.ino      Old bench test sketch (not used)
├── havapaw_ml/                  Machine learning (Python)
│   ├── data/generate_dataset.py Synthetic dataset generator
│   ├── external/                Real public datasets used for calibration
│   ├── train_random_forest.py   Train + evaluate the Random Forest
│   ├── compare_models.py        Compare 5 models
│   ├── make_figures.py          Report charts
│   ├── distill_to_tflite.py     Convert to a TFLite model for the phone
│   ├── export_collar_readings.py Export real readings from Firestore for testing
│   ├── models/                  Saved models
│   └── reports/                 Evaluation reports and figures
├── tools/
│   ├── virtual_collar.py        Simulated collar for testing and demos
│   └── usb_bridge.py            Sends real collar readings via USB when Wi-Fi is not possible
├── docs/
│   ├── ALERTS_AND_COLLAR_SETUP.md  Setup and deployment notes
│   └── PROJECT_GUIDE.md         This file
└── esp32/README.md              Pointer to the current firmware
```

**A rule of thumb used throughout the app:** logic that can be tested without Firebase lives in
`models/` (e.g. `spike_check.dart`, `weekly_summary.dart`), while code that reads/writes data lives in
`services/`. Screens only build the UI and call these.

---

## 4. The collar (ESP32 firmware)

Folder: `HavaPaw_Arduino/havapaw_collar/`. Built with the Arduino IDE (ESP32 core 3.x, board
"ESP32 Dev Module", **Partition Scheme: Huge APP** because the sketch is about 1 MB).

### Hardware and pins

| Part | Measures | Connection |
|---|---|---|
| ESP32 DevKit (ESP32-WROOM-32) | the computer, Wi-Fi, Bluetooth | — |
| MAX30102 | heart rate, SpO2 (optical) | I²C: SDA **GPIO21**, SCL **GPIO22** |
| MPU6050 | acceleration → steps, activity | I²C: same bus |
| DS18B20 | temperature | 1-Wire **GPIO4** (+4.7 kΩ pull-up to 3.3 V) |
| NEO-6M GPS | location | UART2: GPS TX → **GPIO16**, GPS RX → **GPIO17**, 9600 baud |
| LiPo + TP4056 | power and charging | battery voltage via 2×100 kΩ divider to **GPIO34** |
| 3.3 V regulator (TPS63020 buck-boost) | stable 3.3 V from the LiPo | output to ESP32 **3V3** pin |

### `havapaw_sensors.h`
Starts the sensors (`sensorsBegin()`) and returns a `SensorSnapshot` (`sensorsSnapshot()`) with:
heart rate and SpO2 (with "valid" flags), temperature, accelerometer x/y/z in g, a step count over the
last 5 minutes, and battery %. `SENSOR_DEBUG_PRINT 1` prints a line every 2 s to the Serial Monitor.
`BATTERY_ADC_PIN = -1` disables battery reading if no divider is fitted.

### `havapaw_collar.ino`: what it does
- **Setup:** loads saved settings from flash (`Preferences`, namespace `havapaw`): Wi-Fi name and
  password, upload URL, device token and device ID. The device ID defaults to
  `HavaPaw-ESP32-XXXX` (from the chip's MAC). Then it starts Bluetooth, the sensors, GPS and NTP time,
  and joins Wi-Fi if configured.
- **Bluetooth provisioning (BLE GATT):** one service with three characteristics. The UUIDs must match
  `havapaw/lib/services/collar_ble_protocol.dart`.

  | UUID ending | Name | Purpose |
  |---|---|---|
  | `…0001…` | service | HavaPaw collar service |
  | `…0002…` | config (write) | the app writes JSON `{ssid, pass, url, token, deviceId}` in chunks |
  | `…0003…` | status (read/notify) | collar reports `READY`, `WIFI_OK`, `FIREBASE_OK`, errors |
  | `…0004…` | device ID (read) | the app reads the collar's ID |

  After receiving the config the collar saves it, connects to Wi-Fi and immediately uploads one reading
  so the app can show "FIREBASE_OK". Advertising stops 5 minutes after boot once it is set up (saves
  power); power-cycle the collar to pair again.
- **Upload loop:** every 30 s (`POST_INTERVAL_MS`), if heart rate and temperature are valid, it builds
  the JSON (`buildReading()`) and POSTs it with `WiFiClientSecure` + pinned **GTS Root R1/R4**
  certificates. Location is only included if the GPS fix is less than 2 minutes old.
- **Power savings:** CPU at 80 MHz, Bluetooth and Wi-Fi transmit power reduced.
- **`USB_MODE 1`:** no Bluetooth or Wi-Fi at all. Each reading is printed as `DATA {json}` over the USB
  cable and `tools/usb_bridge.py` uploads it. This was added because the prototype board's regulator was
  damaged and could not power the radio (see section 14).
- **`DISABLE_BROWNOUT_DETECTOR`:** bench testing only, keep at 0.

### Power rules (learned the hard way)
- Power the ESP32 through its **3V3 pin from a 3.3 V regulator**, not by connecting the battery to VIN.
  A LiPo (3.7–4.2 V) is too low for the board's own regulator, and connecting the TP4056 OUT+ to VIN
  while USB was plugged in back-fed the board and damaged its regulator.
- Turn the collar's switch off before plugging in USB for uploads.

---

## 5. The backend (Firebase)

Project ID: `havapaw-11e23`. Needs the **Blaze** (pay-as-you-go) plan for Cloud Functions and Secret
Manager; at this scale it stays within the free allowance.

### 5.1 Firestore data model

```
users/{uid}                         name, consent, alertPrefs{push,health,geofence,battery,digest}, onWalk
  ├── pets/{petId}                  name, type (dog/cat), breed, birthday, weight, length, height,
  │   │                             collarId, ownerId, imageBase64, emergency fields
  │   ├── dailyStats/{YYYY-MM-DD}   stepsSum, stepsN, restHrSum, restHrN, activeN, offBodyN   (server-written)
  │   └── journal/{id}              kind (checkin/note/weight), tag, text, weightKg, readingId,
  │                                 heartRate, temperature, createdAt
  ├── collarData/{id}               one reading: deviceId, petId, timestamp, heartRate, temperature,
  │                                 bloodOxygen, steps, accelerometerX/Y/Z, batteryLevel,
  │                                 latitude, longitude, ownerContext (from a check-in)
  ├── alerts/{id}                   type, title, body, severity, petId, createdAt, feedback
  ├── alertState/{petId}            server bookkeeping: counts, lastSent, lowBattery, outside, daily
  ├── geofences/{id}                petId, name, latitude, longitude, radius, isActive, createdAt
  ├── medications/{id}              petId, name, dosage, frequency, startDate, endDate, reminderTimes, isActive
  └── fcmTokens/{token}             phone push tokens
deviceTokens/{deviceId}             uid, petId, token (64 hex chars), createdAt
emergencyAlerts/{id}                ownerId, ... (emergency mode records)
```

Dates in `dailyStats` use **Malaysia time (UTC+8)**, so a day runs from local midnight to midnight.

### 5.2 Security rules (`havapaw/firestore.rules`)
- `users/{uid}/**`: only the signed-in owner can read or write their own data.
- `deviceTokens/{deviceId}`: the owner can create, update or delete their collar's token (exact fields
  and a 64-character token are enforced) but **nobody can read it**. Only the Cloud Function (admin
  access) reads it.
- `emergencyAlerts`: the owner can create and read their own.
- Collar readings cannot be written by clients directly any more; they come in through
  `ingestCollarData`.

### 5.3 Cloud Functions (`havapaw/functions/index.js`)

| Function | Trigger | Region | What it does |
|---|---|---|---|
| `ingestCollarData` | HTTPS POST from the collar | us-central1 | Checks the device token, validates value ranges (`sanitizeReading`), rate limit, writes the reading |
| `onCollarReading` | new `collarData` document | asia-southeast1 | Daily summary, health/deviation/battery/geofence alerts, push notifications |
| `generateVirtualVetAdvice` | called by the app | us-central1 | Builds a prompt from the profile, latest reading, ML result, weekly summary and journal → GPT-4o |
| `dailyDigest` | schedule, 8 pm Malaysia time | us-central1 | One summary push per pet ("Bobby's day: …"), not saved to alert history |

The OpenAI key is stored as the secret `OPENAI_API_KEY` (Secret Manager), never in the code.

### 5.4 `functions/lib/rules.js`: the server's rules
Kept separate from `index.js` so they can be unit tested without Firebase.

- `heartRateThreshold(pet)`: dog 140 / cat 220 bpm; −10 if older than 8, +10 if younger than 2, −5 if
  over 30 kg; clamped to 60–220.
- `temperatureThreshold(pet)`: 39.5 °C; −0.3 if older than 10; +0.5 for cats; clamped to 38–41.
- `healthAlerts()`: high heart rate (severe if 20 bpm over), **stress** (high heart rate with fewer
  than 100 steps), high temperature (severe if 1 °C over).
- `deviationCheck()`: compares heart rate with the pet's mean for the same state (rest/active) over the
  previous 3 days (needs about 30 minutes of data); alerts at **±35 %**.
- `dailySummaryIncrements()`: what each reading adds to `dailyStats`.
- `isOffBody()`: temperature below **32 °C** means the probe is reading room air (collar not worn); such
  readings raise no health alerts and are left out of the baselines.
- `activityGoalMinutes()`, `activeMinutes()`, `digestMessage()`: the activity goal and the evening
  summary text.
- `formatOwnerContext()`: turns the app's weekly summary and journal into prompt text (clipped and
  labelled as owner information, not instructions).
- `isOutsideAllZones()`: geofence check using the haversine distance.

Alerts need **2 abnormal readings in a row** (ignores one-off sensor glitches) and have cooldowns
(15 min health, 5 min geofence). Low battery is sent once below 15 % and re-armed above 25 %. Geofence
alerts are skipped while the owner has **Walk mode** on.

---

## 6. The mobile app (Flutter)

### 6.1 Start-up and navigation
`main.dart` initialises Firebase, push notifications (`NotificationService`), the selected pet, walk
state and sounds, picks the saved language, then runs the app with routes:

`/splash` → `SplashScreen` → `/login` (`AuthWrapper`: login if signed out) → `/home` (`ConsentGate`:
asks for terms and data consent once, then `HomeScreen`).

`HomeScreen` has a bottom navigation bar (`widgets/bottom_nav.dart`) with four tabs:
**Home · Health · Map · Profile**.

### 6.2 Screens (`lib/screens/`)

| Screen | What the user does there |
|---|---|
| `splash_screen` | Logo while loading |
| `login_screen`, `register_screen` | Email/password or Google sign-in, password reset |
| `consent_screen` (`ConsentGate`) | Accept terms and data use (versioned, asked again if it changes) |
| `home_screen` | Welcome, selected pet card, health score, today's steps, safe-zone status with **On a walk** toggle, connect-collar prompt |
| `health_screen` | Live vitals, collar status bar, overall health card, **spike check-in**, health alerts, **Why this status?**, **activity goal**, **walk weather**, medications, buttons to trends, journal, vet report, AI insights |
| `health_trends_screen` | Heart-rate, activity and temperature charts from daily summaries |
| `health_journal_screen` | Weekly summary, weight chart, timeline of alerts/check-ins/notes/weights, add note or weight |
| `alert_history_screen` | Past alerts with "was this useful?" 👍/👎 feedback |
| `ai_insights_screen` | ML prediction with class probabilities, rule-based insights, baseline progress, **Ask the Virtual Vet** |
| `map_screen` | Live pet location (OpenStreetMap via `flutter_map`), create/edit/delete safe zones (geofences) |
| `collar_connection_screen` | Scan for collars over Bluetooth, enter Wi-Fi, pair the collar to a pet |
| `profile_screen` | Add/edit/remove pets (photo, type, breed, birthday, weight, size, collar ID), pet settings |
| `settings_screen` and sub-screens | Account, notifications, sounds/music, language, about, FAQ, help, privacy policy, terms |
| `music_selection_screen`, `audio_player_screen` | Calming music for the pet |

### 6.3 Services (`lib/services/`)

| Service | Responsibility |
|---|---|
| `auth_service` | Firebase Auth: register, login, Google sign-in, sign out, profile |
| `pet_service`, `selected_pet_service` | Pets CRUD; which pet is selected (saved on the phone) |
| `collar_data_service` | Streams the latest reading and reading history (only `ESP32` devices) |
| `daily_summary_service` | Streams `dailyStats` for a pet |
| `esp32_ble_service`, `collar_ble_protocol` | Bluetooth scan, permissions, MTU, write provisioning JSON, read status/ID |
| `health_intelligence_service` | The app's health rules (same thresholds as `rules.js`), health score, activity ratio |
| `baseline_calibration_service` | Personal resting heart-rate baseline (section 7.2) |
| `ml_health_classifier_service` | Loads the TFLite model, builds the 11 features, normalises, classifies |
| `ai_health_insights_service` | Rule-based insight cards (health, exercise, behaviour, nutrition) |
| `virtual_vet_service` | Calls `generateVirtualVetAdvice` with reading, ML result and weekly/journal context |
| `alert_history_service` | Streams alerts, saves feedback |
| `journal_service` | Journal entries, spike check-ins (also tags the reading), weight logs |
| `geofence_service`, `pet_location_service`, `walk_state_service` | Safe zones, pet location, walk mode |
| `medication_service` | Medications CRUD |
| `notification_service` | FCM token registration, local notifications, foreground messages |
| `emergency_mode_service` | Emergency mode for critical readings, live-location sharing |
| `weather_service` | Current weather from Open-Meteo (free, no key), cached 30 min |
| `vet_report_service` | Builds the 30-day PDF report and opens the share sheet |
| `sound_service` | Background music and sound effects |

### 6.4 Models (`lib/models/`)

| Model | What it holds or decides |
|---|---|
| `pet`, `collar_data`, `geofence`, `medication` | Firestore documents as Dart classes |
| `daily_summary` | One day's totals; `restingHeartRate`, `avgStepsPerReading`, `activeMinutes` |
| `journal_entry` | Check-in / note / weight entry, tags, icons, ML label for a check-in |
| `spike_check` | When to ask "what is your pet doing?" and which advice to show |
| `weekly_summary` | This week vs last week (resting HR, activity, alerts, check-ins, notes) |
| `alert_explanation` | The factors shown in "Why this status?" |
| `activity_goal` | Daily active-minutes goal and streak |
| `heat_risk` | Walk safety level from the "feels like" temperature |
| `collar_wear` | Collar-off detection (below 32 °C) |

### 6.5 Widgets, theme and languages
- `widgets/collar_status_bar.dart`: how fresh the last reading is ("2 min ago") and battery.
- `widgets/spike_check_in_card.dart`: the check-in card.
- `widgets/health_insight_cards.dart`: collar-off banner, Why card, goal card, heat card.
- `theme/app_theme.dart`: colours (teal `#0F9B8E`, amber, alert red, slate) and the Material theme.
- **Languages:** English, Bahasa Melayu, Bahasa Indonesia and Simplified Chinese, via `easy_localization`.
  Text in code is written as a key, e.g. `'goal_title'.tr()`, and the text lives in
  `assets/translations/*.json`. Push notifications from the server are in English.

---

## 7. Health logic: thresholds, baselines and alerts

### 7.1 Individual limits
Every pet's limits depend on species, age and weight (same numbers in the app and on the server):

| Limit | Base | Adjustments |
|---|---|---|
| Max heart rate | dog 140, cat 220 bpm | older than 8: −10; younger than 2: +10; heavier than 30 kg: −5 |
| Max temperature | 39.5 °C | older than 10: −0.3; cat: +0.5 |

### 7.2 Personal baseline (`baseline_calibration_service.dart`)
The resting heart rate a pet "normally" has is learned over time:

```
baseline = (n × own_mean + 30 × population_value) / (n + 30)
```

- `population_value` comes from real data: **Invoxia** resting heart rates of 40 dogs (59.7 bpm for
  small/medium, 52.4 for large/giant; adjusted +15 for puppies, −8 for seniors), and 170 bpm for cats.
- `own_mean` is the average of the pet's own daily resting heart rates (readings with ≤150 steps).
- `n` is how many days of data there are. On day 1 the population value dominates; after about 30 days
  the pet's own data counts as much; later it dominates. This is a *Bayesian-style shrinkage estimate*.
- The **model itself is not retrained**: the baseline adapts, and the model receives "how far is the
  heart rate from this pet's baseline" as a feature.

### 7.3 Where alerts come from

| Source | Where | When |
|---|---|---|
| Health rules | server (`rules.js`) + shown in app | heart rate / temperature over limits, stress |
| Baseline deviation | server | ±35 % from the pet's own 3-day normal for the same state; GPT-4o writes the note |
| Low activity | app | today's activity < 65 % of the 3-day average (after enough readings) |
| Geofence | server | outside every active safe zone (unless walk mode is on) |
| Low battery | server | < 15 % |
| ML state | app (AI Insights, Why card) | the model's predicted state and confidence are shown, not pushed |

### 7.4 Features that make the alerts smarter
- **Spike check-in:** when a fresh reading spikes (over a limit, or ≥35 % above the baseline), the
  Health screen asks *"What is Bobby doing?"* (playing, resting, scared, just ate, not sure) and shows
  advice for the answer. A spike while *resting* is treated as most serious. The answer is saved to the
  journal and on the reading (`ownerContext`), so it can later be used as an ML label.
- **Collar-off detection:** temperature below 32 °C means the probe reads room air. The app shows a banner
  and pauses alerts, and the server ignores those readings for alerts and baselines.
- **Why this status?:** lists each measurement against the pet's baseline or limit (e.g. "100 bpm, +43 %
  vs Bobby's normal (70 bpm)"), plus the ML result and confidence: *explainable* alerts.
- **Alert feedback:** owners rate alerts as useful or not, which gives evidence for evaluation.

### 7.5 Activity, goals and weather
- **Active minutes:** a reading with more than 150 steps (over the last 5 minutes) counts as active;
  each reading covers 30 s, so `activeN × 0.5` = active minutes.
- **Goal:** cats 20 min; dogs under 12 kg 40 min, 12–55 kg 60 min, over 55 kg 45 min; puppies (<1 year)
  and seniors (>8) at most 30 min. A streak counts days in a row the goal was met.
- **Walk weather:** Open-Meteo "feels like" temperature: below 28 °C good, 28–32 warm, 32–38 hot (short
  walks only), 38+ too hot. Flat-faced breeds (pug, bulldog, shih tzu, boxer, Persian, …) and seniors
  move up one level.

---

## 8. Machine learning pipeline

Folder: `havapaw_ml/`. Python with pandas, scikit-learn, TensorFlow.

### 8.1 The problem
Classify one reading (plus context) into **resting, active, stressed or anomaly**.

### 8.2 The 11 features

| # | Feature | Meaning |
|---|---|---|
| 1 | `heart_rate` | bpm |
| 2 | `temperature` | °C |
| 3 | `spo2` | blood oxygen % (97.5 if missing) |
| 4 | `activity_index` | x² + y² + z² of the accelerometer (g²) |
| 5 | `steps` | steps in the last 5 minutes |
| 6 | `activity_ratio_3day` | today's activity ÷ 3-day average (capped at 5) |
| 7 | `hr_deviation_pct` | % difference from the pet's personal baseline |
| 8 | `temp_deviation_c` | °C above/below the pet's temperature limit |
| 9 | `age` | years |
| 10 | `weight` | kg |
| 11 | `species_encoded` | 1 = dog, 0 = cat |

Features 6–8 are the **personalised** ones: the same heart rate means different things for different pets.

### 8.3 Data
No public dataset has labelled collar readings for pets in these four states, so the training data is
**synthetic but calibrated with real data** (`data/generate_dataset.py`, `external/`):

- 500 simulated pets × 40 readings = **20,000 readings**.
- **Real data used:** cat accelerometer data (Kaggle) and dog accelerometer data (Mendeley) set the
  activity-index distributions; **Invoxia** resting heart rates of 40 dogs set the dog baselines.
- **Real data for validation only:** ECG recordings of 4 dogs (Zenodo 19383015) checked the
  heart-rate thresholds.
- Still synthetic: cat heart rate, steps, SpO2, temperature, and the *stressed*/*anomaly* classes.

### 8.4 Training and evaluation (`train_random_forest.py`)
- **Random Forest**: 200 trees, max depth 12, `class_weight="balanced"`.
- **Grouped splitting by pet** (`StratifiedGroupKFold`): a pet's readings are never in both training and
  test data, so the scores show performance on *unseen pets*.
- Results (simulated data): 5-fold CV accuracy **98.2 %**, held-out test pets **97.8 %**; the weakest
  classes are *stressed* and *anomaly* (recall about 0.91–0.97).
- `--real-csv` tests on real labelled readings; `--mix-real` trains on synthetic + other real pets and
  tests on each real pet in turn.
- Writes `reports/rf_evaluation_report.md`, including limitations.

### 8.5 Model comparison (`compare_models.py`, `make_figures.py`)
Same grouped 5-fold CV for every model:

| Model | Accuracy | Macro F1 |
|---|---|---|
| Baseline (always "resting") | 39.3 % | 0.141 |
| Logistic Regression | 95.7 % | 0.929 |
| Decision Tree | 97.3 % | 0.956 |
| **Random Forest** | **98.1 %** | **0.968** |
| SVM (RBF) | 97.7 % | 0.962 |

Random Forest was chosen for the best macro F1, robustness to unscaled mixed features, built-in feature
importance (explainability), and fast inference. Figures in `reports/figures/`: class distribution,
feature box plots, correlation heatmap, confusion matrix, feature importance, model comparison.

### 8.6 Getting the model onto the phone (`distill_to_tflite.py`)
Random Forests cannot be converted to TensorFlow Lite directly, so the forest is **distilled**: a small
neural network (11 → 32 → 16 → 4, ReLU, softmax) is trained to copy the forest's predictions, then saved
as `pet_health_classifier.tflite` with the feature means and standard deviations in
`model_metadata.json`. The app normalises features the same way and runs the model **on the phone** (no
internet needed, data stays on the device for this step).

### 8.7 Using real collar data (`export_collar_readings.py`)
Downloads a pet's real readings from Firestore and rebuilds exactly the same 11 features the app uses
(same baseline formula and constants). Labels come from a `--labels` CSV of time ranges, or
automatically from **spike check-ins** (Playing → active, Scared/stressed → stressed). Then run
`train_random_forest.py --real-csv data/real_readings.csv`.

---

## 9. LLM features (GPT-4o)

| Feature | Where | Input | Output |
|---|---|---|---|
| **Virtual Vet** | AI Insights screen → `generateVirtualVetAdvice` | pet profile, latest reading, activity ratio, ML state and confidence, optional owner question, weekly summary, last 7 days of journal | 3–5 sentences + up to 3 next steps, never a diagnosis, ends with a disclaimer |
| **Deviation note** | `onCollarReading` | pet, state, current vs baseline heart rate, temperature, SpO2 | one short push-notification body (≤300 chars); falls back to a fixed text if GPT is unavailable |

Design choices: the system prompts forbid diagnoses, ask for calm wording, and require referencing the
actual readings; temperature 0.3–0.4 for consistent answers; owner-written text is clipped and marked as
information, not instructions (prompt-injection safety). The app shows a "not a substitute for a vet"
disclaimer.

---

## 10. Developer tools: virtual collar and USB bridge

### `tools/virtual_collar.py`: a simulated collar
Sends readings exactly like the real collar (same endpoint, same token header), using the same pet maths
as the app.

```
python tools/virtual_collar.py setup --key <service-account.json> --email <login> --pet Bobby
python tools/virtual_collar.py seed  --key <service-account.json>     # 3 normal days of history
python tools/virtual_collar.py run --interval 30                      # live readings
```
While running, type: `resting`, `active`, `stressed`, `deviation`, `anomaly fever|hypoxia|tachycardia|dehydration`,
`battery 10`, `outside`, `home`, `send`, `status`, `quit`. The `dataset` sub-command writes simulated
readings to CSV and shows how the Random Forest classifies them.

### `tools/usb_bridge.py`: real collar without Wi-Fi
With `#define USB_MODE 1` the collar prints readings over USB; the bridge reads the COM port and
uploads them.
```
python tools/usb_bridge.py setup --key <service-account.json> --email <login> --pet Bobby --device-id HavaPaw-ESP32-XXXX
python tools/usb_bridge.py run --port COM5
```

Both tools save their token in a git-ignored JSON file. **Never commit the service-account key.**

---

## 11. Security and privacy

- **Authentication:** Firebase Auth (email/password, Google).
- **Per-user data isolation:** Firestore rules allow each user to access only `users/{their uid}`.
- **Collar authentication:** each collar has a random 64-character token created by the app during
  pairing. The token is stored in `deviceTokens` (unreadable by clients) and on the collar; the server
  compares it in constant time.
- **Transport security:** HTTPS with pinned Google root certificates on the collar.
- **Input validation:** the server rejects out-of-range values and rate-limits each device.
- **Secrets:** the OpenAI key is in Secret Manager; service-account keys are kept out of the repository
  (`.gitignore`).
- **Consent:** users accept terms and data use before using the app (versioned).
- **Data minimisation:** pet photos are stored as small base64 images; no documents are uploaded.

---

## 12. Testing

| Part | Command | What is tested |
|---|---|---|
| Flutter app | `cd havapaw && flutter test` | 80 tests: health rules, baselines, daily summaries, ML feature vector, spike check-ins, journal, weekly summary, explanations, goals, heat risk, collar-off, PDF report, splash screen |
| Cloud Functions | `cd havapaw/functions && npm test` | 15 tests: thresholds, alerts, deviation, daily summaries, collar-off, goals, digest text, Virtual Vet context |
| Static checks | `flutter analyze` | Lints and type errors |
| ML | `python train_random_forest.py`, `compare_models.py` | Grouped CV and held-out test pets |
| End to end | virtual collar `run` | Real backend, alerts and push notifications |

---

## 13. How to run, build and deploy

```
# App
cd havapaw
flutter pub get
flutter run                         # debug on a connected phone
flutter build apk --release         # release APK (build/app/outputs/flutter-apk/app-release.apk)

# Backend
cd havapaw/functions && npm install
cd .. && firebase deploy --only functions
firebase deploy --only firestore:rules

# ML (from havapaw_ml/)
python data/generate_dataset.py
python train_random_forest.py
python compare_models.py && python make_figures.py
python distill_to_tflite.py         # then copy the .tflite + metadata into havapaw/assets/ml/
```
Firmware: open `HavaPaw_Arduino/havapaw_collar/havapaw_collar.ino` in the Arduino IDE, board ESP32 Dev
Module, Partition Scheme **Huge APP**, upload at 115200 if uploads drop.

---

## 14. Known limitations

Be upfront about these in the report and viva:

1. **Model accuracy is on simulated data.** 98 % shows the pipeline works, not real-world accuracy.
   Real labelled pet data (e.g. from check-ins) is needed for a true evaluation.
2. **Hardware:** the prototype ESP32's 3.3 V regulator was damaged by battery back-feed (measured VIN
   4.6–5.1 V but 3V3 only 3.02–3.2 V), so the radio browned out. Fix: power through an external 3.3 V
   buck-boost (TPS63020) or replace the board; meanwhile USB mode + bridge sends real sensor data.
3. **Optical heart rate through fur** is noisy; MAX30102 readings on animals are less reliable than ECG.
4. **Active minutes** assume one reading every 30 s and start counting from the deploy that added them.
5. **SpO2, cat heart rate and the stressed/anomaly classes** are synthetic in training.
6. **LLM output** is guidance only and can be wrong; it is constrained by prompts and disclaimers.
7. **Server push texts** are English only.

---

## 15. Likely viva questions

**Why a Random Forest?** Best macro F1 in a fair comparison, handles mixed unscaled features, resists
overfitting by averaging many trees, gives feature importance, small and fast.

**How do you avoid data leakage?** Splits are grouped by pet, so the model is always tested on pets it
never saw.

**How is it personalised?** Individual limits from species/age/weight, a learned resting baseline that
moves from population values to the pet's own data, and features that measure deviation from that
baseline.

**Why distil to a neural network?** TFLite cannot run scikit-learn forests; distillation keeps the
forest's behaviour in a tiny on-device model.

**Why both rules and ML?** Rules give guaranteed, explainable alerts for dangerous values; ML combines
many signals to recognise states like stress that a single threshold misses.

**What does the LLM add?** It turns numbers and model outputs into clear, context-aware guidance the owner
can act on, while the prompts forbid diagnoses.

**How is the collar secured?** Per-device secret token, server-side validation, unreadable token store,
HTTPS with pinned certificates, rate limiting.

**How do you reduce false alarms?** Two consecutive abnormal readings, cooldowns, walk mode, collar-off
detection, owner check-ins, and alert feedback.

**What would you do next?** Collect real labelled data through check-ins and retrain/evaluate on it,
replace the damaged board, add ECG-grade sensing, and run a user study.

---

## 16. Glossary

| Term | Meaning |
|---|---|
| BLE / GATT | Bluetooth Low Energy and its "characteristics" used to exchange data |
| Provisioning | Sending Wi-Fi details and the token to the collar during pairing |
| FCM | Firebase Cloud Messaging (push notifications) |
| Firestore | Firebase's cloud database (collections of documents) |
| Cloud Function | Server code that runs on demand (HTTP call, database change, schedule) |
| Geofence / safe zone | A circle on the map; leaving it triggers an alert |
| Baseline | The pet's normal resting heart rate |
| Grouped cross-validation | Testing where each pet's data stays together in one fold |
| Macro F1 | Average F1 over classes, so small classes count equally |
| Distillation | Training a small model to imitate a bigger one |
| TFLite | TensorFlow Lite, a format for running models on phones |
| Brownout | A supply-voltage dip that resets the ESP32 |
