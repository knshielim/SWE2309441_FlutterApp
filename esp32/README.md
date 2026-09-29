# HavaPaw ESP32 Collar

This firmware works with the Flutter **Connect Collar** screen.

## What it does

1. **Bluetooth** – advertises as `HavaPaw-ESP32-XXXX` and accepts WiFi + account binding from the app  
2. **WiFi** – joins the 2.4 GHz network you enter in the app  
3. **Firestore** – posts sensor readings to `users/{uid}/collarData`

## Setup (Arduino IDE)

1. Install **ESP32** board support (Espressif)  
2. Install library **ArduinoJson** (Benoit Blanchon)  
3. Open `havapaw_collar.ino`  
4. Board: **ESP32 Dev Module** (or your board)  
5. Upload

## App pairing

1. Power the ESP32  
2. In HavaPaw: select a pet → **Connect Collar** → **Scan**  
3. Tap `HavaPaw-ESP32-…`  
4. Enter **2.4 GHz** WiFi SSID + password  
5. Wait for success – `pet.collarId` is saved automatically  

## Firestore rules

Unauthenticated REST writes from the ESP32 are blocked by default Firebase rules. For demos you can temporarily allow writes to `collarData`, or harden later with a Cloud Function / device token.

## Sensors

The sketch posts demo heart rate / temperature / steps / battery. Replace those with your real sensors (MAX30102, MPU6050, GPS, etc.) in `postCollarReading()`.
