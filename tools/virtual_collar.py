# Virtual collar: sends simulated readings like the ESP32 does, or writes them to CSV
import argparse
import json
import math
import random
import secrets
import sys
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "havapaw_ml"))
from export_collar_readings import (  # noqa: E402  (same pet maths as the app)
    FEATURE_COLUMNS, build_rows, pet_age, population_resting_hr, temperature_threshold,
)

CONFIG_PATH = Path(__file__).resolve().parent / "virtual_collar.json"
CALIBRATION_PATH = ROOT / "havapaw_ml" / "external" / "external_calibration.json"
MODEL_PATH = ROOT / "havapaw_ml" / "models" / "random_forest_model.joblib"
INGEST_URL = "https://us-central1-havapaw-11e23.cloudfunctions.net/ingestCollarData"
DEVICE_ID = "HavaPaw-ESP32-SIM"
DEFAULT_HOME = (2.8323, 101.7068)  # XMUM campus
TZ = ZoneInfo("Asia/Kuala_Lumpur")

STATES = ["resting", "active", "stressed", "anomaly", "deviation"]
ANOMALIES = ["fever", "hypoxia", "tachycardia", "dehydration"]


# Pet limits (same rules as the app and rules.js)
def heart_rate_threshold(pet, at):
    age = pet_age(pet.get("birthday", ""), at)
    limit = 220.0 if str(pet.get("type", "dog")).lower() == "cat" else 140.0
    if age > 8:
        limit -= 10
    elif age < 2:
        limit += 10
    if float(pet.get("weight") or 0) > 30:
        limit -= 5
    return min(max(limit, 60.0), 220.0)


def load_activity_quantiles():
    if not CALIBRATION_PATH.exists():
        return {}
    cal = json.loads(CALIBRATION_PATH.read_text(encoding="utf-8"))
    return cal.get("activity_index", {})


ACTIVITY = load_activity_quantiles()


def activity_index(species, moving):
    block = ACTIVITY.get(species)
    if not block:
        return random.gauss(1.6, 0.3) if moving else random.gauss(1.02, 0.03)
    q = block["active" if moving else "resting"]
    pos = random.uniform(0, len(q) - 1)
    i = int(pos)
    j = min(i + 1, len(q) - 1)
    return q[i] + (q[j] - q[i]) * (pos - i)


def accelerometer(index):
    # random direction with |a|^2 = activity index
    m = math.sqrt(max(index, 0.0))
    theta = random.uniform(0, math.pi)
    phi = random.uniform(0, 2 * math.pi)
    return (m * math.sin(theta) * math.cos(phi), m * math.sin(theta) * math.sin(phi), m * math.cos(theta))


# One reading for a state (same rules as generate_dataset.py)
def make_reading(pet, state, anomaly="fever", at=None):
    at = at or datetime.now(timezone.utc)
    species = str(pet.get("type", "dog")).lower()
    base_hr = population_resting_hr(pet, at)
    max_hr = heart_rate_threshold(pet, at)
    max_temp = temperature_threshold(pet, at)
    base_temp = 38.8 if species == "cat" else 38.5
    moving = state == "active"

    if state == "resting":
        steps, hr, temp, spo2 = random.gauss(20, 15), random.gauss(base_hr, 6), random.gauss(base_temp, 0.15), random.gauss(97.5, 1.0)
    elif state == "active":
        steps, hr, temp, spo2 = random.gauss(600, 150), random.gauss(min(max_hr - 5, base_hr * 1.35), 10), random.gauss(base_temp + 0.3, 0.2), random.gauss(97.0, 1.2)
    elif state == "stressed":
        steps, hr, temp, spo2 = random.gauss(15, 10), random.gauss(max_hr + 15, 8), random.gauss(base_temp + 0.2, 0.2), random.gauss(96.5, 1.3)
    elif state == "deviation":
        # resting, but heart rate 45% above normal while still under the fixed limit
        steps, hr, temp, spo2 = random.gauss(20, 10), min(base_hr * 1.45, max_hr - 5), random.gauss(base_temp, 0.15), random.gauss(97.0, 1.0)
    else:
        steps = random.gauss(25, 20)
        if anomaly == "fever":
            hr, temp, spo2 = random.gauss(base_hr * 1.15, 10), random.gauss(max_temp + 1.2, 0.3), random.gauss(96.5, 1.2)
        elif anomaly == "hypoxia":
            hr, temp, spo2 = random.gauss(base_hr * 1.2, 10), random.gauss(base_temp, 0.2), random.gauss(89.0, 2.5)
        elif anomaly == "tachycardia":
            hr, temp, spo2 = random.gauss(max_hr + 30, 10), random.gauss(base_temp, 0.2), random.gauss(96.0, 1.5)
        else:  # dehydration
            hr, temp, spo2 = random.gauss(max_hr + 10, 8), random.gauss(max_temp + 0.6, 0.25), random.gauss(96.0, 1.5)

    ax, ay, az = accelerometer(activity_index(species, moving))
    return {
        "heartRate": int(round(min(max(hr, 30), 260))),
        "temperature": round(min(max(temp, 35.5), 42.5), 2),
        "bloodOxygen": int(round(min(max(spo2, 80), 100))),
        "steps": int(max(0, round(steps))),
        "accelerometerX": round(ax, 3),
        "accelerometerY": round(ay, 3),
        "accelerometerZ": round(az, 3),
    }


# Firebase setup (needs a service-account key)
def firestore_client(key):
    import firebase_admin
    from firebase_admin import credentials, firestore
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(key))
    return firestore.client()


def cmd_setup(args):
    from firebase_admin import auth
    db = firestore_client(args.key)
    uid = auth.get_user_by_email(args.email).uid
    user = db.collection("users").document(uid)
    pets = [d for d in user.collection("pets").stream() if args.pet in (d.id, d.to_dict().get("name"))]
    if not pets:
        raise SystemExit(f"No pet called {args.pet} for {args.email}.")
    pet_doc = pets[0]
    pet = pet_doc.to_dict()

    token = secrets.token_hex(32)
    db.collection("deviceTokens").document(DEVICE_ID).set(
        {"uid": uid, "petId": pet_doc.id, "token": token, "createdAt": datetime.now(timezone.utc)})
    pet_doc.reference.update({"collarId": DEVICE_ID})

    home, radius = list(DEFAULT_HOME), 50.0
    zones = user.collection("geofences").where("petId", "==", pet_doc.id).where("isActive", "==", True).limit(1).stream()
    for z in zones:
        zone = z.to_dict()
        home, radius = [zone["latitude"], zone["longitude"]], float(zone.get("radius", 50))

    config = {
        "url": INGEST_URL, "deviceId": DEVICE_ID, "token": token, "uid": uid, "petId": pet_doc.id,
        "pet": {"name": pet.get("name"), "type": pet.get("type", "dog"),
                "birthday": pet.get("birthday", ""), "weight": pet.get("weight", 20)},
        "home": home, "radius": radius,
    }
    CONFIG_PATH.write_text(json.dumps(config, indent=2), encoding="utf-8")
    print(f"Virtual collar {DEVICE_ID} paired with {pet.get('name')}. Saved {CONFIG_PATH.name}.")


def cmd_seed(args):
    # 3 normal days so the 3-day averages and the baseline alert work straight away
    config = load_config()
    db = firestore_client(args.key)
    pet = config["pet"]
    now = datetime.now(timezone.utc)
    base_hr = population_resting_hr(pet, now)
    pet_ref = db.collection("users").document(config["uid"]).collection("pets").document(config["petId"])
    daily = {}
    for d in range(1, 4):
        day = now - timedelta(days=d)
        local_day = day.astimezone(TZ).strftime("%Y-%m-%d")
        pet_ref.collection("dailyStats").document(local_day).set({
            "date": local_day, "stepsSum": 120 * 2880, "stepsN": 2880,
            "restHrSum": base_hr * 2000, "restHrN": 2000,
        })
        n = 400
        daily[day.strftime("%Y-%m-%d")] = {"restSum": base_hr * n, "restN": n,
                                           "activeSum": base_hr * 1.35 * n, "activeN": n}
    db.collection("users").document(config["uid"]).collection("alertState").document(config["petId"]).set(
        {"daily": daily}, merge=True)
    print(f"Seeded 3 normal days (resting heart rate {base_hr:.0f} bpm) for {pet['name']}.")


def load_config():
    if not CONFIG_PATH.exists():
        raise SystemExit("Run the setup command first.")
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


# Live sending
class VirtualCollar:
    def __init__(self, config, interval, state):
        self.config = config
        self.interval = interval
        self.state = state
        self.anomaly = "fever"
        self.battery = 90.0
        self.outside = False
        self.running = True

    def location(self):
        lat, lng = self.config["home"]
        if self.outside:
            lat += 3 * self.config["radius"] / 111_000  # 3 zone radii north
        return lat + random.gauss(0, 0.00003), lng + random.gauss(0, 0.00003)

    def send(self):
        body = make_reading(self.config["pet"], self.state, self.anomaly)
        lat, lng = self.location()
        body.update({
            "deviceId": self.config["deviceId"],
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "batteryLevel": int(self.battery),
            "latitude": round(lat, 6),
            "longitude": round(lng, 6),
        })
        self.battery = max(0.0, self.battery - 0.05)
        request = urllib.request.Request(
            self.config["url"], data=json.dumps(body).encode(), method="POST",
            headers={"Content-Type": "application/json", "X-Device-Token": self.config["token"]})
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                code = response.status
        except urllib.error.HTTPError as e:
            code = e.code
        except urllib.error.URLError as e:
            code = f"no connection ({e.reason})"
        label = self.state + (f" ({self.anomaly})" if self.state == "anomaly" else "")
        print(f"[{datetime.now():%H:%M:%S}] {label}: HR {body['heartRate']}, {body['temperature']} C, "
              f"SpO2 {body['bloodOxygen']}%, steps {body['steps']}, battery {body['batteryLevel']}%"
              f"{', OUTSIDE zone' if self.outside else ''} -> {code}")

    def loop(self):
        while self.running:
            self.send()
            for _ in range(int(self.interval * 10)):
                if not self.running:
                    return
                time.sleep(0.1)


HELP = """Commands:
  resting | active | stressed | deviation
  anomaly [fever|hypoxia|tachycardia|dehydration]
  battery <0-100>     outside | home
  send                status | help | quit"""


def cmd_run(args):
    collar = VirtualCollar(load_config(), max(args.interval, 5), args.state)
    print(f"Virtual collar for {collar.config['pet']['name']}, one reading every {collar.interval:g} s.")
    print(HELP)
    threading.Thread(target=collar.loop, daemon=True).start()
    while True:
        try:
            words = input().strip().lower().split()
        except (EOFError, KeyboardInterrupt):
            break
        if not words:
            continue
        cmd = words[0]
        if cmd in ("quit", "exit", "q"):
            break
        elif cmd in STATES:
            collar.state = cmd
            if cmd == "anomaly" and len(words) > 1:
                if words[1] not in ANOMALIES:
                    print(f"Unknown anomaly. Use one of: {', '.join(ANOMALIES)}")
                    continue
                collar.anomaly = words[1]
            print(f"State is now {cmd}" + (f" ({collar.anomaly})" if cmd == "anomaly" else ""))
        elif cmd == "battery" and len(words) > 1 and words[1].isdigit():
            collar.battery = float(min(int(words[1]), 100))
            print(f"Battery set to {int(collar.battery)}%")
        elif cmd in ("outside", "home"):
            collar.outside = cmd == "outside"
            print("Moved outside the safe zone" if collar.outside else "Back home")
        elif cmd == "send":
            collar.send()
        elif cmd == "status":
            print(f"state={collar.state} anomaly={collar.anomaly} battery={int(collar.battery)}% "
                  f"outside={collar.outside}")
        else:
            print(HELP)
    collar.running = False


# CSV datasets (no Firebase needed)
def cmd_dataset(args):
    pet = {"id": "sim-pet", "name": args.name, "type": args.species, "weight": args.weight,
           "birthday": (datetime.now() - timedelta(days=int(args.age * 365.25))).strftime("%Y-%m-%d")}
    today = datetime.now(TZ).replace(hour=0, minute=0, second=0, microsecond=0)
    history = []

    # 3 normal days first (walks 7-9 am and 5-7 pm), like a real collar's history
    for d in range(3, 0, -1):
        start = today - timedelta(days=d)
        for i in range(288):  # one reading every 5 minutes
            at = start + timedelta(minutes=5 * i)
            state = "active" if 7 <= at.hour < 9 or 17 <= at.hour < 19 else "resting"
            history.append({"id": f"h{d}-{i}", "timestamp": at, **make_reading(pet, state, at=at)})

    # Today: each state on its own, from 9 am, as if the pet was like this all morning
    rows = []
    for k, item in enumerate(s.strip() for s in args.state.split(",")):
        state, _, anomaly = item.partition(":")
        if state not in STATES:
            raise SystemExit(f"Unknown state {state}. Use: {', '.join(STATES)} (anomaly:fever etc.)")
        t = today + timedelta(hours=9)
        todays = []
        for i in range(args.count):
            t += timedelta(seconds=30)
            todays.append({"id": f"s{k}-{i}", "timestamp": t, **make_reading(pet, state, anomaly or "fever", at=t)})
        ids = {r["id"] for r in todays}
        for row in build_rows(pet, history + todays, TZ):
            if row["doc_id"] in ids:
                row["label"] = "" if state == "deviation" else state  # deviation is only for the alert test
                row["scenario"] = item
                rows.append(row)

    import pandas as pd
    df = pd.DataFrame(rows)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out, index=False)
    print(f"Wrote {len(df)} readings to {out}")

    if MODEL_PATH.exists():
        import joblib
        model = joblib.load(MODEL_PATH)["model"]
        df["predicted"] = [["resting", "active", "stressed", "anomaly"][p] for p in model.predict(df[FEATURE_COLUMNS])]
        print("\nHow the Random Forest classifies them:")
        print(pd.crosstab(df["scenario"], df["predicted"]).to_string())


def main():
    parser = argparse.ArgumentParser(description="Virtual HavaPaw collar")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("setup", help="pair a virtual collar with one of your pets")
    p.add_argument("--key", required=True, help="Firebase service-account JSON")
    p.add_argument("--email", required=True, help="your login email")
    p.add_argument("--pet", required=True, help="pet name or id")
    p.set_defaults(func=cmd_setup)

    p = sub.add_parser("seed", help="add 3 normal days of history for the paired pet")
    p.add_argument("--key", required=True)
    p.set_defaults(func=cmd_seed)

    p = sub.add_parser("run", help="send live readings and change state by typing commands")
    p.add_argument("--interval", type=float, default=30, help="seconds between readings (min 5)")
    p.add_argument("--state", choices=STATES, default="resting")
    p.set_defaults(func=cmd_run)

    p = sub.add_parser("dataset", help="write simulated readings to CSV")
    p.add_argument("--state", default="resting,active,stressed,anomaly",
                   help="comma list, e.g. resting,anomaly:fever,anomaly:hypoxia")
    p.add_argument("--count", type=int, default=100, help="readings per state")
    p.add_argument("--species", choices=["dog", "cat"], default="dog")
    p.add_argument("--weight", type=float, default=20.0)
    p.add_argument("--age", type=float, default=4.0)
    p.add_argument("--name", default="SimPet")
    p.add_argument("--out", default=str(ROOT / "havapaw_ml" / "data" / "simulated_readings.csv"))
    p.set_defaults(func=cmd_dataset)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
