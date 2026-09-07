"""
Synthetic pet vitals dataset generator for HavaPaw's Random Forest health classifier.

WHY SYNTHETIC: No public dataset exists with this exact sensor schema (continuous
heart rate + SpO2 + temperature + tri-axis accelerometer + steps, labeled by
health/activity state) for companion animals. This mirrors the approach taken by
the papers already cited in the FYP literature review (e.g. Malar et al. 2026,
Reyu & Princess 2024), who built individualized baselines from published breed/
age/weight physiological ranges rather than a single off-the-shelf dataset.

Ranges used below are grounded in sources already cited in the proposal:
- Dog HR 60-140 bpm, Cat HR 140-220 bpm (breedHeartRateRanges in
  health_intelligence_service.dart, sourced from the FYP lit review)
- Normal canine/feline body temperature ~37.5-39.2 degC (Klune et al., 2021;
  general veterinary reference ranges)
- SpO2 healthy resting range ~95-100% (MAX30102 datasheet / Saputra et al., 2021
  sensor accuracy figures)
- "Stress" defined per Malar et al. (2026): elevated HR + low activity
- "Low activity" defined as < 50% of a 3-day rolling average (proposal's own
  context-aware logic, already implemented in health_intelligence_service.dart)

Classes (matches Figure 3 of the proposal - "Random Forest classifier ...
classifies activity state: resting, active, stressed, anomaly"):
    0 = resting     - low movement, HR/temp/SpO2 within individual baseline
    1 = active       - elevated movement, HR appropriately elevated for exertion
    2 = stressed      - elevated HR WITH low movement (context-aware distress)
    3 = anomaly    - fever, hypoxia, tachycardia/bradycardia at rest, or dehydration
                        signature (elevated HR + elevated temp + low activity)

Each row represents one collar reading window, already paired with the pet's
individualized baseline (computed the same way as
HealthIntelligenceService.getIndividualizedHeartRateThreshold /
getIndividualizedTemperatureThreshold in the Flutter app), so the model learns
the SAME personalization logic the proposal promises rather than population-wide
thresholds.
"""

import numpy as np
import pandas as pd

RNG = np.random.default_rng(42)

SPECIES = ["dog", "cat"]
SIZE_CLASS = ["toy", "small", "medium", "large", "giant"]  # widened to cover breed weight extremes

N_PETS = 500          # distinct synthetic pet profiles (widened for the extra size classes)
READINGS_PER_PET = 40  # readings per pet across states


def individualized_hr_threshold(species, age, weight):
    """Mirrors HealthIntelligenceService.getIndividualizedHeartRateThreshold (Dart)."""
    base_max = 220.0 if species == "cat" else 140.0
    if age > 8:
        base_max -= 10
    elif age < 2:
        base_max += 10
    if weight > 30:
        base_max -= 5
    return float(np.clip(base_max, 60.0, 220.0))


def individualized_temp_threshold(species, age):
    """Mirrors HealthIntelligenceService.getIndividualizedTemperatureThreshold (Dart)."""
    threshold = 39.5
    if age > 10:
        threshold -= 0.3
    if species == "cat":
        threshold += 0.5
    return float(np.clip(threshold, 38.0, 41.0))


def resting_hr_baseline(species, size_class, age, weight):
    if species == "cat":
        base = RNG.normal(170, 14)  # widened spread to cover small kittens -> large Maine Coons
    else:
        base = {"toy": RNG.normal(135, 12),      # e.g. Chihuahua, Yorkshire Terrier (~1-4kg)
                "small": RNG.normal(110, 10),     # e.g. Shih Tzu, Beagle (~4-12kg)
                "medium": RNG.normal(90, 8),       # e.g. Border Collie, Bulldog (~10-30kg)
                "large": RNG.normal(75, 8),        # e.g. Labrador, Boxer (~25-55kg)
                "giant": RNG.normal(65, 7)}[size_class]  # e.g. Great Dane, Mastiff (~45-90kg)
    if age < 1:
        base += 15  # puppies/kittens run hotter HR
    elif age > 8:
        base -= 8
    return float(np.clip(base, 45, 210))


def make_pet_profile(pet_id):
    species = RNG.choice(SPECIES, p=[0.6, 0.4])
    size_class = RNG.choice(SIZE_CLASS) if species == "dog" else "n/a"
    age = float(np.clip(RNG.exponential(4.0), 0.15, 18))  # widened for very young/senior extremes
    if species == "cat":
        # covers small kittens (~1.5kg) through large-breed cats like Maine Coon (~10-12kg)
        weight = float(np.clip(RNG.normal(4.5, 1.8), 1.5, 12))
    else:
        weight = {
            "toy": RNG.normal(2.8, 1.0),      # Chihuahua, teacup breeds (~1-5kg)
            "small": RNG.normal(8, 2.5),       # Shih Tzu, Beagle (~4-12kg)
            "medium": RNG.normal(20, 5),        # Border Collie, Bulldog (~10-30kg)
            "large": RNG.normal(38, 8),         # Labrador, Boxer (~25-55kg)
            "giant": RNG.normal(65, 12),        # Great Dane, Mastiff, St. Bernard (~45-90kg)
        }[size_class]
        weight = float(np.clip(weight, 1.0, 90))

    return {
        "pet_id": pet_id,
        "species": species,
        "size_class": size_class,
        "age": round(age, 2),
        "weight": round(weight, 2),
        "hr_baseline": resting_hr_baseline(species, size_class, age, weight),
        "hr_threshold": individualized_hr_threshold(species, age, weight),
        "temp_threshold": individualized_temp_threshold(species, age),
    }


def sample_reading(profile, state):
    hr_baseline = profile["hr_baseline"]
    hr_threshold = profile["hr_threshold"]
    temp_threshold = profile["temp_threshold"]
    base_temp = 38.5 if profile["species"] == "dog" else 38.8

    if state == "resting":
        activity_index = RNG.normal(1.02, 0.03)          # ~gravity only, accel magnitude^2 near 1g^2
        steps = int(max(0, RNG.normal(20, 15)))
        heart_rate = RNG.normal(hr_baseline, 6)
        temperature = RNG.normal(base_temp, 0.15)
        spo2 = RNG.normal(97.5, 1.0)
        activity_ratio = RNG.normal(1.0, 0.15)             # vs 3-day rolling avg

    elif state == "active":
        activity_index = RNG.normal(1.6, 0.3)
        steps = int(max(0, RNG.normal(600, 150)))
        heart_rate = RNG.normal(min(hr_threshold - 5, hr_baseline * 1.35), 10)
        temperature = RNG.normal(base_temp + 0.3, 0.2)
        spo2 = RNG.normal(97.0, 1.2)
        activity_ratio = RNG.normal(1.6, 0.3)

    elif state == "stressed":
        # context-aware: high HR + LOW movement (Malar et al., 2026)
        activity_index = RNG.normal(1.03, 0.04)
        steps = int(max(0, RNG.normal(15, 10)))
        heart_rate = RNG.normal(hr_threshold + 15, 8)
        temperature = RNG.normal(base_temp + 0.2, 0.2)
        spo2 = RNG.normal(96.5, 1.3)
        activity_ratio = RNG.normal(0.35, 0.15)

    else:  # anomaly: fever / hypoxia / dehydration signature / arrhythmia-like
        subtype = RNG.choice(["fever", "hypoxia", "tachycardia_rest", "dehydration"])
        activity_index = RNG.normal(1.05, 0.05)
        steps = int(max(0, RNG.normal(25, 20)))
        activity_ratio = RNG.normal(0.5, 0.2)
        if subtype == "fever":
            heart_rate = RNG.normal(hr_baseline * 1.15, 10)
            temperature = RNG.normal(temp_threshold + 1.2, 0.3)
            spo2 = RNG.normal(96.5, 1.2)
        elif subtype == "hypoxia":
            heart_rate = RNG.normal(hr_baseline * 1.2, 10)
            temperature = RNG.normal(base_temp, 0.2)
            spo2 = RNG.normal(89.0, 2.5)
        elif subtype == "tachycardia_rest":
            heart_rate = RNG.normal(hr_threshold + 30, 10)
            temperature = RNG.normal(base_temp, 0.2)
            spo2 = RNG.normal(96.0, 1.5)
            activity_index = RNG.normal(1.02, 0.03)  # resting posture, abnormal HR
        else:  # dehydration signature: elevated HR + elevated temp + reduced activity
            heart_rate = RNG.normal(hr_threshold + 10, 8)
            temperature = RNG.normal(temp_threshold + 0.6, 0.25)
            spo2 = RNG.normal(96.0, 1.5)

    heart_rate = float(np.clip(heart_rate, 30, 260))
    temperature = float(np.clip(temperature, 35.5, 42.5))
    spo2 = float(np.clip(spo2, 80, 100))
    activity_index = float(max(0.9, activity_index))
    activity_ratio = float(max(0.0, activity_ratio))

    return {
        "heart_rate": round(heart_rate, 1),
        "temperature": round(temperature, 2),
        "spo2": round(spo2, 1),
        "activity_index": round(activity_index, 3),
        "steps": steps,
        "activity_ratio_3day": round(activity_ratio, 3),
        # deviation features -- the "individualized baseline" signal from the proposal
        "hr_deviation_pct": round((heart_rate - hr_baseline) / hr_baseline * 100, 2),
        "temp_deviation_c": round(temperature - temp_threshold, 2),
    }


def build_dataset():
    rows = []
    state_weights = {"resting": 0.40, "active": 0.30, "stressed": 0.15, "anomaly": 0.15}
    label_map = {"resting": 0, "active": 1, "stressed": 2, "anomaly": 3}

    for pet_id in range(N_PETS):
        profile = make_pet_profile(pet_id)
        states = RNG.choice(
            list(state_weights.keys()),
            size=READINGS_PER_PET,
            p=list(state_weights.values()),
        )
        for state in states:
            reading = sample_reading(profile, state)
            row = {
                "pet_id": profile["pet_id"],
                "species": profile["species"],
                "size_class": profile["size_class"],
                "age": profile["age"],
                "weight": profile["weight"],
                **reading,
                "label": label_map[state],
                "label_name": state,
            }
            rows.append(row)

    df = pd.DataFrame(rows)
    return df.sample(frac=1.0, random_state=42).reset_index(drop=True)


if __name__ == "__main__":
    df = build_dataset()
    df.to_csv("/home/claude/havapaw_ml/data/pet_health_dataset.csv", index=False)
    print(f"Generated {len(df)} rows across {df['pet_id'].nunique()} synthetic pet profiles")
    print(df["label_name"].value_counts())
