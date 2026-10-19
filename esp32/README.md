# Collar firmware has moved

The sketch that used to live here posted **random demo values** and wrote to Firestore without
authentication. It has been removed.

Use **`HavaPaw_Arduino/havapaw_collar/havapaw_collar.ino`** (with `havapaw_sensors.h`). It reads the real
MAX30102, MPU6050, DS18B20 and NEO-6M GPS, is provisioned over BLE by the app, and uploads to the
`ingestCollarData` Cloud Function with a per-device secret token.

`HavaPaw_Arduino/HavaPaw_Arduino.ino` is a separate bench sketch (deep sleep + Realtime Database).
It is not used by the app.

Firestore rules now live in `havapaw/firestore.rules`.
