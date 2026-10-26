# Exports real collar readings from Firestore to CSV
import argparse
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pandas as pd

FEATURE_COLUMNS = [
    "heart_rate", "temperature", "spo2", "activity_index", "steps",
    "activity_ratio_3day", "hr_deviation_pct", "temp_deviation_c",
    "age", "weight", "species_encoded",
]
LABEL_NAMES = ["resting", "active", "stressed", "anomaly"]

# constants mirrored from the Dart app
LEARNING_PERIOD_DAYS = 3          # HealthIntelligenceService.learningPeriodDays
PRIOR_PSEUDO_DAYS = 30.0          # BaselineCalibrationService._priorPseudoDays
RESTING_STEPS_CUTOFF = 150        # BaselineCalibrationService._restingStepsCutoff
DEFAULT_SPO2 = 97.5               # MLHealthClassifierService.buildFeatureVector
ACTIVITY_RATIO_CLIP = 5.0


# pet profile (HealthIntelligenceService)
def pet_age(birthday, at):
    try:
        b = datetime.fromisoformat(str(birthday)[:10])
    except ValueError:
        return 0
    age = at.year - b.year
    if (at.month, at.day) < (b.month, b.day):
        age -= 1
    return age


def dog_size_class(weight):
    if weight < 5:
        return "toy"
    if weight < 12:
        return "small"
    if weight < 30:
        return "medium"
    if weight < 55:
        return "large"
    return "giant"


def population_resting_hr(pet, at):
    age = pet_age(pet.get("birthday", ""), at)
    if str(pet.get("type", "dog")).lower() == "cat":
        base = 170.0
    else:
        base = {"toy": 59.7, "small": 59.7, "medium": 59.7, "large": 52.4, "giant": 52.4}[
            dog_size_class(float(pet.get("weight") or 0))]
    if age < 1:
        base += 15
    elif age > 8:
        base -= 8
    return min(max(base, 45.0), 210.0)


def temperature_threshold(pet, at):
    age = pet_age(pet.get("birthday", ""), at)
    t = 39.5
    if age > 10:
        t -= 0.3
    if str(pet.get("type", "dog")).lower() == "cat":
        t += 0.5
    return min(max(t, 38.0), 41.0)


# features for every reading of one pet
def build_rows(pet, readings, tz):
    readings = sorted(readings, key=lambda r: r["timestamp"])
    steps_by_day = defaultdict(list)         # day -> steps of each reading
    resting_hr_by_day = defaultdict(list)    # day -> heart rates of resting readings
    rows = []
    for r in readings:
        local = r["timestamp"].astimezone(tz)
        day = local.date()
        steps = r.get("steps")
        hr = r.get("heartRate")

        # The app's history includes the current reading, so add it first.
        if steps is not None:
            steps_by_day[day].append(steps)
        if hr is not None and (steps or 0) <= RESTING_STEPS_CUTOFF:
            resting_hr_by_day[day].append(float(hr))

        temp = r.get("temperature")
        if hr is None or temp is None:
            continue

        # activity_ratio_3day: today's mean steps per reading / mean of the 3 earlier days
        earlier = sorted(d for d in steps_by_day if d < day)[-LEARNING_PERIOD_DAYS:]
        ratio = 1.0
        if earlier and steps_by_day.get(day):
            three_day = sum(sum(steps_by_day[d]) / len(steps_by_day[d]) for d in earlier) / len(earlier)
            if three_day > 0:
                ratio = (sum(steps_by_day[day]) / len(steps_by_day[day])) / three_day

        # hr baseline: population prior blended with the pet's own resting days
        prior = population_resting_hr(pet, local)
        daily_means = [sum(v) / len(v) for v in resting_hr_by_day.values() if v]
        if daily_means:
            own = sum(daily_means) / len(daily_means)
            n = len(daily_means)
            baseline = (n * own + PRIOR_PSEUDO_DAYS * prior) / (n + PRIOR_PSEUDO_DAYS)
        else:
            baseline = prior

        ax, ay, az = r.get("accelerometerX"), r.get("accelerometerY"), r.get("accelerometerZ")
        accel_measured = None not in (ax, ay, az)
        activity_index = ax * ax + ay * ay + az * az if accel_measured else 0.0
        spo2 = r.get("bloodOxygen")

        rows.append({
            "doc_id": r.get("id", ""),
            "pet_id": pet.get("id", ""),
            "pet_name": pet.get("name", ""),
            "time_local": local.strftime("%Y-%m-%d %H:%M:%S"),
            "species": str(pet.get("type", "dog")).lower(),
            "heart_rate": float(hr),
            "temperature": float(temp),
            "spo2": float(spo2) if spo2 is not None else DEFAULT_SPO2,
            "activity_index": activity_index if activity_index > 0 else 1.0,
            "steps": float(steps or 0),
            "activity_ratio_3day": min(ratio, ACTIVITY_RATIO_CLIP),
            "hr_deviation_pct": (float(hr) - baseline) / baseline * 100,
            "temp_deviation_c": float(temp) - temperature_threshold(pet, local),
            "age": float(pet_age(pet.get("birthday", ""), local)),
            "weight": float(pet.get("weight") or 0),
            "species_encoded": 1.0 if str(pet.get("type", "")).lower() == "dog" else 0.0,
            "spo2_measured": spo2 is not None,
            "accel_measured": accel_measured,
            "label": "",
            "notes": "",
        })
    return rows


def apply_label_ranges(df, labels_csv):
    ranges = pd.read_csv(labels_csv)
    times = pd.to_datetime(df["time_local"])
    for _, lr in ranges.iterrows():
        start, end = pd.to_datetime(lr["start"]), pd.to_datetime(lr["end"])
        pet = str(lr["pet"]).strip()
        hit = ((df["pet_name"] == pet) | (df["pet_id"] == pet)) & (times >= start) & (times <= end)
        df.loc[hit, "label"] = str(lr["label"]).strip().lower()
        print(f"  {pet} {lr['start']} - {lr['end']}: {int(hit.sum())} readings -> {lr['label']}")
    return df


# Firestore
def parse_timestamp(value):
    if value is None:
        return None
    if hasattr(value, "isoformat") and not isinstance(value, str):   # Firestore Timestamp / datetime
        return value if value.tzinfo else value.replace(tzinfo=ZoneInfo("UTC"))
    try:
        t = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    return t if t.tzinfo else t.replace(tzinfo=ZoneInfo("UTC"))


def load_from_firestore(key, uid, email, pet_filter):
    import firebase_admin
    from firebase_admin import auth, credentials, firestore

    firebase_admin.initialize_app(credentials.Certificate(key))
    if not uid:
        uid = auth.get_user_by_email(email).uid
    db = firestore.client()
    user = db.collection("users").document(uid)

    pets = []
    for doc in user.collection("pets").stream():
        p = doc.to_dict()
        p["id"] = doc.id
        if pet_filter and pet_filter not in (doc.id, p.get("name")):
            continue
        pets.append(p)
    if not pets:
        raise SystemExit("No matching pets for this user.")

    out = []
    for pet in pets:
        readings = []
        for doc in user.collection("collarData").where("petId", "==", pet["id"]).stream():
            d = doc.to_dict()
            if "ESP32" not in str(d.get("deviceId", "")):     # same filter as CollarDataService
                continue
            t = parse_timestamp(d.get("timestamp"))
            if t is None:
                continue
            d["timestamp"], d["id"] = t, doc.id
            readings.append(d)
        print(f"{pet.get('name', pet['id'])}: {len(readings)} collar readings")
        out.append((pet, readings))
    return out


def main():
    ap = argparse.ArgumentParser(description="Export collar readings from Firestore to CSV")
    ap.add_argument("--key", required=True, help="Firebase service-account JSON (keep it out of the repo)")
    who = ap.add_mutually_exclusive_group(required=True)
    who.add_argument("--uid", help="Firebase Auth uid of the account that owns the pets")
    who.add_argument("--email", help="email of that account (looked up in Firebase Auth)")
    ap.add_argument("--pet", help="only this pet (name or id)")
    ap.add_argument("--since", help="first local date to include, YYYY-MM-DD")
    ap.add_argument("--until", help="last local date to include, YYYY-MM-DD")
    ap.add_argument("--tz", default="Asia/Kuala_Lumpur", help="time zone for days and labels")
    ap.add_argument("--labels", help="optional CSV of pet,start,end,label time ranges")
    ap.add_argument("--out", default=str(Path(__file__).resolve().parent / "data" / "real_readings.csv"))
    args = ap.parse_args()

    tz = ZoneInfo(args.tz)
    rows = []
    for pet, readings in load_from_firestore(args.key, args.uid, args.email, args.pet):
        rows += build_rows(pet, readings, tz)   # full history, so baselines are right
    if not rows:
        raise SystemExit("No readings with both heart rate and temperature.")

    df = pd.DataFrame(rows)
    day = pd.to_datetime(df["time_local"]).dt.date
    if args.since:
        df = df[day >= datetime.fromisoformat(args.since).date()]
    if args.until:
        df = df[day <= datetime.fromisoformat(args.until).date()]
    if args.labels:
        print("Applying label ranges:")
        df = apply_label_ranges(df, args.labels)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out, index=False)
    labelled = int((df["label"] != "").sum())
    print(f"Wrote {len(df)} readings to {out} ({labelled} labelled)")
    print("Next: fill in the label column, then run  python train_random_forest.py --real-csv " + str(out))


if __name__ == "__main__":
    main()
