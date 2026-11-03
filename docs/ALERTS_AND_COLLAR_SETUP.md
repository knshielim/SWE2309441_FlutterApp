# Alerts, secure collar upload and consent: setup

## 1. Deploy the backend (once, and after any change in `havapaw/functions` or `firestore.rules`)

```bash
cd havapaw/functions && npm install && npm test      # 8 tests should pass
cd .. 
firebase functions:secrets:set OPENAI_API_KEY         # only if not set already
firebase deploy --only functions,firestore:rules
```

`ingestCollarData` is served at
`https://us-central1-<project>.cloudfunctions.net/ingestCollarData`.
If your functions are not in `us-central1`, edit `CollarConfig.ingestUrl` in
`havapaw/lib/config/collar_config.dart`.

The first deploy of a Firestore trigger can take a few minutes; the Cloud Functions logs
(`firebase functions:log`) show `onCollarReading` runs.

Firestore may ask for composite indexes the first time the geofence query runs
(`petId` + `isActive`). Click the link in the log to create it.

## 2. Collar

1. Arduino libraries: ArduinoJson 6.x, SparkFun MAX3010x, Adafruit MPU6050, OneWire,
   DallasTemperature, **TinyGPSPlus**.
2. In `havapaw_sensors.h` set `BATTERY_ADC_PIN` (for example 34) and `BATTERY_DIVIDER_RATIO`
   to match your voltage divider. Without this no battery level is sent and the low-battery
   push cannot fire.
3. Wire the NEO-6M: GPS TX -> GPIO16, GPS RX -> GPIO17, 3.3 V, GND.
4. Flash `HavaPaw_Arduino/havapaw_collar/havapaw_collar.ino`, then pair the collar in the app
   (Collar connection screen). Pairing registers the secret token and writes it to the collar.
5. To pair again, power-cycle the collar (BLE advertising stops 2 minutes after boot once paired).

## 3. Test checklist

| What | How | Expected |
|---|---|---|
| Upload | Watch Serial Monitor | `Ingest POST 200` every ~30 s |
| Rejected upload | Change the token in `curl` | HTTP 401 |
| GPS | Take the collar outside | latitude/longitude appear in `collarData`; map moves |
| Geofence | Make a 50 m zone, walk out with Walk mode OFF | push "left the safe zone" after 2 readings |
| Walk mode | Same, Walk mode ON | no push |
| Health alert | Lower a pet's weight/age in the profile or temporarily lower the limit in `rules.js`, or post a test reading | push after 2 abnormal readings, then at most one per 15 min |
| Baseline deviation | Needs at least one earlier day of readings (60+ in the same resting/active state). Then send two resting readings 35%+ above that baseline, or edit `daily` in `alertState/<petId>` to fake a baseline | push written by GPT-4, e.g. "heart rate is 40% higher than usual"; `alerts` doc has `generatedBy` |
| Alert history | Health screen -> Alert history; tap 👍 or 👎 on an alert | alert listed; its `users/<uid>/alerts` doc gets `feedback: useful / not_useful` |
| Daily summary | After a few uploads, open `users/<uid>/pets/<petId>/dailyStats/<today>` | `stepsSum`, `stepsN`, `restHrSum`, `restHrN` increase with each reading |
| Low battery | Battery under 15 % | one push, re-arms after 25 % |
| Settings | Turn "Health alerts" off | no health push |
| Consent | New account | consent screen before Home |

Test reading with curl (replace values):

```bash
curl -X POST "$INGEST_URL" -H "Content-Type: application/json" \
  -H "X-Device-Token: <64-hex token from Firestore deviceTokens/<deviceId>>" \
  -d '{"deviceId":"HavaPaw-ESP32-ABCD","heartRate":170,"temperature":38.6,"steps":5,"batteryLevel":12}'
```

## 4. Collar TLS

The collar checks the server certificate against Google's root CAs (GTS Root R1 and R4,
valid until 2036) instead of accepting any certificate. It needs the time from NTP first;
until the clock is set it reports `TIME_WAIT` and skips that upload.

## 5. Daily summaries and alert feedback

`onCollarReading` also keeps one small document per pet per day
(`users/<uid>/pets/<petId>/dailyStats/<YYYY-MM-DD>`, Malaysia time). The app reads these for the
3-day activity average, the low-activity alert, the 30-day heart-rate baseline and the ML features,
instead of downloading every reading (about 2,900 a day). Days before the new functions were deployed
have no summary, so the baselines start from the deploy date.

The Alert history screen lists `users/<uid>/alerts` and lets owners rate each alert useful or not
useful. Export these (`feedback` field) to report alert relevance in the evaluation.

## 6. Testing without the collar (virtual collar)

`tools/virtual_collar.py` behaves like the ESP32: it sends readings in the same format to
`ingestCollarData` with its own device token, so the app, alerts and Firestore work as with the real
collar. It needs Python with `firebase-admin` (setup/seed only) and `pandas scikit-learn joblib`
(dataset only).

```
python tools/virtual_collar.py setup --key <service-account.json> --email <your login> --pet Hava
python tools/virtual_collar.py seed --key <service-account.json>
python tools/virtual_collar.py run
```

`setup` pairs a virtual collar (`HavaPaw-ESP32-SIM`) with the pet and uses its active safe zone as
home. `seed` adds 3 normal days of history so the 3-day averages and the "higher than usual" alert
work immediately. While `run` is sending (every 30 s), type:

| Command | Effect |
|---|---|
| `resting`, `active`, `stressed` | readings for that state |
| `anomaly fever` / `hypoxia` / `tachycardia` / `dehydration` | readings for that anomaly |
| `deviation` | resting, but heart rate 45% above normal (tests the GPT-4 baseline alert) |
| `battery 12` | set the battery level |
| `outside` / `home` | move outside the safe zone / back |
| `send`, `status`, `quit` | send now, show state, stop |

Alerts need 2 abnormal readings in a row, then wait 15 minutes (delete `users/<uid>/alertState/<petId>`
to test again). Re-pair the real collar afterwards; this changes the pet's `collarId`.

Labelled CSV without Firebase (same columns as `export_collar_readings.py`):

```
python tools/virtual_collar.py dataset --state resting,active,stressed,anomaly:fever --count 100
python tools/virtual_collar.py dataset --species cat --weight 4.5 --out cat.csv
```

It prints how the Random Forest classifies each scenario. The file can be used with
`python havapaw_ml/train_random_forest.py --real-csv <file>` to demo the real-data path, but it is
simulated data, so do not report it as a real-pet result.
