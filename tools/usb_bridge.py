# USB bridge: reads the real collar's readings over the USB cable and sends them to the server
# (used when the collar is in USB_MODE because its Bluetooth/Wi-Fi cannot be powered)
import argparse
import json
import secrets
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

CONFIG_PATH = Path(__file__).resolve().parent / "usb_bridge.json"
INGEST_URL = "https://us-central1-havapaw-11e23.cloudfunctions.net/ingestCollarData"


def cmd_setup(args):
    # Registers a device token for the real collar's ID, like the app does over Bluetooth
    import firebase_admin
    from firebase_admin import auth, credentials, firestore

    if "ESP32" not in args.device_id:
        raise SystemExit("Use the ID the collar prints, e.g. HavaPaw-ESP32-A1B2")
    firebase_admin.initialize_app(credentials.Certificate(args.key))
    db = firestore.client()
    uid = auth.get_user_by_email(args.email).uid
    user = db.collection("users").document(uid)
    pets = [d for d in user.collection("pets").stream() if args.pet in (d.id, d.to_dict().get("name"))]
    if not pets:
        raise SystemExit(f"No pet called {args.pet} for {args.email}.")
    pet_doc = pets[0]

    token = secrets.token_hex(32)
    db.collection("deviceTokens").document(args.device_id).set(
        {"uid": uid, "petId": pet_doc.id, "token": token, "createdAt": datetime.now(timezone.utc)})
    pet_doc.reference.update({"collarId": args.device_id})

    config = {"url": INGEST_URL, "deviceId": args.device_id, "token": token}
    CONFIG_PATH.write_text(json.dumps(config, indent=2), encoding="utf-8")
    print(f"Collar {args.device_id} paired with {pet_doc.to_dict().get('name')}. Saved {CONFIG_PATH.name}.")


def post(config, reading):
    reading["deviceId"] = config["deviceId"]   # the token belongs to this ID
    req = urllib.request.Request(
        config["url"], data=json.dumps(reading).encode(), method="POST",
        headers={"Content-Type": "application/json", "X-Device-Token": config["token"]})
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            return res.status, res.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()
    except urllib.error.URLError as e:
        return 0, str(e.reason)


def cmd_run(args):
    import serial  # pip install pyserial

    if not CONFIG_PATH.exists():
        raise SystemExit("Run  python tools/usb_bridge.py setup ...  first.")
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    print(f"Listening on {args.port} for {config['deviceId']} (Ctrl+C to stop)")

    while True:
        try:
            with serial.Serial(args.port, 115200, timeout=2) as port:
                while True:
                    line = port.readline().decode("utf-8", errors="replace").strip()
                    if not line:
                        continue
                    if not line.startswith("DATA "):
                        print(f"  collar: {line}")
                        continue
                    try:
                        reading = json.loads(line[5:])
                    except json.JSONDecodeError:
                        print("  skipped a broken line")
                        continue
                    if args.dry_run:
                        print(f"  reading: {reading}")
                        continue
                    code, text = post(config, reading)
                    stamp = datetime.now().strftime("%H:%M:%S")
                    print(f"{stamp} HR {reading.get('heartRate')} temp {reading.get('temperature')} -> {code} {text[:80]}")
        except serial.SerialException as e:
            print(f"Cannot open {args.port} ({e}). Close the Arduino Serial Monitor. Retrying in 3 s...")
            time.sleep(3)
        except KeyboardInterrupt:
            print("Stopped.")
            return


def main():
    parser = argparse.ArgumentParser(description="Send the real collar's USB readings to HavaPaw")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("setup", help="pair the real collar with one of your pets")
    p.add_argument("--key", required=True, help="Firebase service-account JSON (keep it out of the repo)")
    p.add_argument("--email", required=True, help="your login email")
    p.add_argument("--pet", required=True, help="pet name or id")
    p.add_argument("--device-id", required=True, help="ID printed by the collar, e.g. HavaPaw-ESP32-A1B2")
    p.set_defaults(func=cmd_setup)

    p = sub.add_parser("run", help="forward readings from the USB port")
    p.add_argument("--port", required=True, help="e.g. COM5 on Windows, /dev/ttyUSB0 on Linux")
    p.add_argument("--dry-run", action="store_true", help="print readings without sending")
    p.set_defaults(func=cmd_run)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
