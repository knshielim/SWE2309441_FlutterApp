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
