"""
Calibrates HavaPaw's synthetic-data generator against real, public datasets.

WHY THIS EXISTS
No public dataset has the collar's full schema (heart rate + temperature + SpO2 +
accelerometer + steps, labelled resting/active/stressed/anomaly), so the Random
Forest is still trained on generated data. What the public datasets CAN do is
replace guessed distributions in the generator with measured ones:

  * Kaggle "Cat Activity Detection"  -> real accelerometer activity_index for cats
                                         (resting vs active)
  * Mendeley Data vxhx934tbn (dogs)  -> real accelerometer activity_index for dogs
                                         (optional; neck sensor = collar position)
  * Zenodo 8020390 (Invoxia dogs)    -> real resting heart rate by weight/age, used
                                         to CHECK the generator's resting baselines

activity_index follows the app: x^2 + y^2 + z^2 of ONE accelerometer sample, in g
(HealthIntelligenceService.calculateActivityIndex). Resting is therefore about 1.0.

USAGE (run from the havapaw_ml folder):
    python external/calibrate_from_external.py
    python external/calibrate_from_external.py --cat path/to/archive.zip --invoxia path/to/dataset.csv
    python external/calibrate_from_external.py --mendeley-dir external/raw/mendeley

Raw data is NOT committed (hundreds of MB). Put it in external/raw/ (gitignored).
The small output files ARE committed:
    external/external_calibration.json        (read by data/generate_dataset.py)
    external/external_calibration_report.md   (tables for the FYP report)
"""

import argparse
import ast
import json
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"

Q = np.linspace(0, 100, 101)   # store 101 quantiles per distribution
G2_CLIP = 16.0                 # MPU6050 at +/-4 g: |a|^2 cannot meaningfully exceed 16 per axis
MIN_DOGS_FOR_HR_OVERRIDE = 5   # size classes with fewer dogs keep the literature value

# --- label groupings (edit these if you disagree with a mapping) --------------
CAT_RESTING = {"Resting"}
CAT_ACTIVE = {"Walking", "Running"}
# Grooming, Eating/Drinking, Scratching, Pooping/Urinating are excluded on purpose:
# they are neither clearly resting nor clearly active.
DOG_RESTING = ("lying", "sitting", "standing")
DOG_ACTIVE = ("walking", "trotting", "galloping")
# sniffing, synchronization and undefined rows are excluded.

# Same size classes as HealthIntelligenceService.dogSizeClass (kg)
def size_class(weight):
    if weight < 5:
        return "toy"
    if weight < 12:
        return "small"
    if weight < 30:
        return "medium"
    if weight < 55:
        return "large"
    return "giant"

# Literature baselines currently used by generate_dataset.py / the Dart app
LITERATURE_DOG_RESTING_HR = {"toy": 135, "small": 110, "medium": 90, "large": 75, "giant": 65}
SIZE_ORDER = ["toy", "small", "medium", "large", "giant"]


# ----------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------
def _quantiles(x):
    return np.round(np.percentile(np.clip(x, 0, G2_CLIP), Q), 4).tolist()


def _stats(x):
    x = np.clip(x, 0, G2_CLIP)
    return {
        "n": int(len(x)),
        "mean": round(float(x.mean()), 3),
        "sd": round(float(x.std()), 3),
        "p5": round(float(np.percentile(x, 5)), 3),
        "p50": round(float(np.percentile(x, 50)), 3),
        "p95": round(float(np.percentile(x, 95)), 3),
    }


def _activity_block(resting, active, extra=None):
    resting = np.asarray(resting, dtype=np.float32)
    active = np.asarray(active, dtype=np.float32)
    p95_rest = np.percentile(resting, 95)
    block = {
        "resting": _quantiles(resting),
        "active": _quantiles(active),
        "summary": {
            "resting": _stats(resting),
            "active": _stats(active),
            # How much of the 'active' data a single sample cannot tell apart from rest
            "active_share_above_resting_p95": round(float((active > p95_rest).mean()), 3),
        },
    }
    if extra:
        block["summary"].update(extra)
    return block


# ----------------------------------------------------------------------------
# Kaggle cat dataset
# ----------------------------------------------------------------------------
def load_cat(path):
    df = pd.read_csv(path, usecols=["Acc_x", "Acc_y", "Acc_z", "label"])
    ai = df.Acc_x**2 + df.Acc_y**2 + df.Acc_z**2
    resting = ai[df.label.isin(CAT_RESTING)].to_numpy()
    active = ai[df.label.isin(CAT_ACTIVE)].to_numpy()
    counts = df.label.value_counts().to_dict()
    return _activity_block(resting, active, extra={"label_counts": {k: int(v) for k, v in counts.items()}})


# ----------------------------------------------------------------------------
# Mendeley dog dataset (optional)
# ----------------------------------------------------------------------------
def load_mendeley(folder):
    needed = ["ANeck_x", "ANeck_y", "ANeck_z", "Behavior_1"]
    resting, active, dogs, files_used = [], [], set(), 0
    for f in sorted(Path(folder).rglob("*.csv")):
        header = set(pd.read_csv(f, nrows=0).columns)
        if not set(needed) <= header:
            continue  # e.g. DogInfo.csv
        cols = needed + (["DogID"] if "DogID" in header else [])
        # DogMoveData.csv is large (100 Hz), so read it in chunks; chunksize is a
        # multiple of 10, so taking every 10th row (-> 10 Hz) stays evenly spaced.
        # A single-sample distribution is unaffected by this thinning.
        for df in pd.read_csv(f, usecols=cols, chunksize=500_000):
            df = df.iloc[::10]
            ai = df.ANeck_x**2 + df.ANeck_y**2 + df.ANeck_z**2
            beh = df.Behavior_1.astype("string").str.lower().fillna("")
            is_rest = beh.str.contains("|".join(DOG_RESTING), regex=True)
            is_act = beh.str.contains("|".join(DOG_ACTIVE), regex=True)
            resting.append(ai[is_rest].to_numpy())
            active.append(ai[is_act].to_numpy())
            if "DogID" in df:
                dogs.update(df.DogID.dropna().unique().tolist())
        files_used += 1
    if not files_used:
        return None
    resting, active = np.concatenate(resting), np.concatenate(active)
    if len(resting) == 0 or len(active) == 0:
        return None
    return _activity_block(resting, active, extra={"n_dogs": len(dogs), "files_used": files_used})


# ----------------------------------------------------------------------------
# Invoxia dog vitals
# ----------------------------------------------------------------------------
def load_invoxia(path):
    df = pd.read_csv(path)
    rows = []
    for pet, w, a, seg in zip(df.pet_id, df.weight, df.age, df.segments_hr):
        if isinstance(seg, str):
            for s in ast.literal_eval(seg):
                rows.append((pet, w, a, s["value"]))
    h = pd.DataFrame(rows, columns=["pet", "weight", "age", "hr"])
    dogs = h.groupby("pet").agg(weight=("weight", "first"), age=("age", "first"), hr=("hr", "median")).reset_index()
    dogs["size_class"] = dogs.weight.map(size_class)

    by_class = {}
    override = {}
    for sc in SIZE_ORDER:
        sub = dogs[dogs.size_class == sc]
        if len(sub) == 0:
            continue
        median = float(sub.hr.median())
        by_class[sc] = {
            "n_dogs": int(len(sub)),
            "median_hr": round(median, 1),
            "p25": round(float(sub.hr.quantile(0.25)), 1),
            "p75": round(float(sub.hr.quantile(0.75)), 1),
            "literature_baseline": LITERATURE_DOG_RESTING_HR[sc],
            "gap_vs_literature": round(median - LITERATURE_DOG_RESTING_HR[sc], 1),
        }
        if len(sub) >= MIN_DOGS_FOR_HR_OVERRIDE:
            override[sc] = round(median, 1)

    X = np.c_[np.ones(len(dogs)), dogs.weight, dogs.age]
    coef = np.linalg.lstsq(X, dogs.hr, rcond=None)[0]
    resid_sd = float(np.std(dogs.hr - X @ coef))
    return {
        "n_dogs": int(len(dogs)),
        "n_segments": int(len(h)),
        "hr_percentiles_5_50_95": [round(float(v), 1) for v in np.percentile(h.hr, [5, 50, 95])],
        "by_size_class": by_class,
        "dog_resting_hr_override": override,   # only used if USE_EXTERNAL_DOG_HR = True in the generator
        "between_dog_sd": round(float(dogs.hr.std()), 1),
        "fit_hr_vs_weight_age": {
            "intercept": round(float(coef[0]), 2),
            "per_kg": round(float(coef[1]), 3),
            "per_year": round(float(coef[2]), 3),
            "residual_sd": round(resid_sd, 1),
            "r_weight": round(float(dogs[["weight", "hr"]].corr().iloc[0, 1]), 2),
            "r_age": round(float(dogs[["age", "hr"]].corr().iloc[0, 1]), 2),
        },
    }


# ----------------------------------------------------------------------------
# report
# ----------------------------------------------------------------------------
def write_report(path, cal):
    L = ["# External dataset calibration report", ""]
    L.append("Generated by `external/calibrate_from_external.py`. Values below come from real public data; "
             "everything not listed here (steps, SpO2, temperature, stressed/anomaly labels) is still synthetic.")
    L.append("")
    L.append("## Accelerometer activity_index (x^2 + y^2 + z^2 of one sample, in g)")
    L.append("")
    L.append("| Species | State | n samples | mean | sd | p5 | median | p95 |")
    L.append("|---|---|---|---|---|---|---|---|")
    for species, block in cal["activity_index"].items():
        for state in ("resting", "active"):
            s = block["summary"][state]
            L.append(f"| {species} | {state} | {s['n']:,} | {s['mean']} | {s['sd']} | {s['p5']} | {s['p50']} | {s['p95']} |")
    L.append("")
    for species, block in cal["activity_index"].items():
        share = block["summary"]["active_share_above_resting_p95"]
        L.append(f"- **{species}:** only {share*100:.1f}% of active samples exceed the resting 95th percentile, "
                 "so one accelerometer sample separates rest from activity poorly. "
                 "Steps or a windowed measure must carry most of that distinction.")
    inv = cal.get("invoxia")
    if inv:
        L += ["", "## Dog resting heart rate (Invoxia, per-dog median of heart-rate segments)", ""]
        L.append(f"{inv['n_dogs']} dogs, {inv['n_segments']:,} segments; 5th/50th/95th percentile: "
                 f"{inv['hr_percentiles_5_50_95']} (assumed bpm - confirm against the dataset README).")
        L.append("")
        L.append("| Size class | dogs | median HR | IQR | literature baseline | gap |")
        L.append("|---|---|---|---|---|---|")
        for sc, v in inv["by_size_class"].items():
            L.append(f"| {sc} | {v['n_dogs']} | {v['median_hr']} | {v['p25']}-{v['p75']} | "
                     f"{v['literature_baseline']} | {v['gap_vs_literature']:+} |")
        f = inv["fit_hr_vs_weight_age"]
        L.append("")
        L.append(f"Linear fit: HR = {f['intercept']} + {f['per_kg']} x weight(kg) + {f['per_year']} x age(yr), "
                 f"residual sd {f['residual_sd']} bpm; correlation with weight {f['r_weight']}, with age {f['r_age']}.")
    path.write_text("\n".join(L) + "\n", encoding="utf-8")


# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cat", default=str(RAW / "Main_File_All_Activites.csv"), help="cat CSV (or the Kaggle .zip)")
    ap.add_argument("--invoxia", default=str(RAW / "dataset.csv"), help="Zenodo 8020390 dataset.csv")
    ap.add_argument("--mendeley-dir", default=str(RAW / "mendeley"), help="folder with the Mendeley dog CSVs")
    ap.add_argument("--out", default=str(HERE / "external_calibration.json"))
    args = ap.parse_args()

    cal = {
        "meta": {
            "sources": {
                "cat_activity": "Kaggle: Cat Activity Detection (arifulislaminje) - cite the original paper",
                "dog_activity": "Mendeley Data vxhx934tbn v4 (Vehkaoja et al.)",
                "dog_hr": "Zenodo record 8020390, Dog Health Vitals Dataset (Invoxia)",
            },
            "assumptions": [
                "activity_index = x^2+y^2+z^2 of a single accelerometer sample in g",
                "Invoxia segment values treated as beats per minute",
                "Kaggle cat file has no cat ID or sampling rate, so it cannot be split by animal or windowed in time",
            ],
        },
        "activity_index": {},
    }

    if Path(args.cat).exists():
        print("Reading cat data ...")
        cal["activity_index"]["cat"] = load_cat(args.cat)
    else:
        print(f"[skip] cat data not found at {args.cat}")

    if Path(args.mendeley_dir).exists():
        print("Reading Mendeley dog data ...")
        block = load_mendeley(args.mendeley_dir)
        if block:
            cal["activity_index"]["dog"] = block
        else:
            print("[skip] no usable Mendeley files (need ANeck_x/y/z and Behavior_1 columns)")
    else:
        print(f"[skip] Mendeley folder not found at {args.mendeley_dir}")

    if Path(args.invoxia).exists():
        print("Reading Invoxia data ...")
        cal["invoxia"] = load_invoxia(args.invoxia)
    else:
        print(f"[skip] Invoxia data not found at {args.invoxia}")

    if not cal["activity_index"] and "invoxia" not in cal:
        raise SystemExit("No input data found. Put the raw files in external/raw/ or pass paths.")

    out = Path(args.out)
    out.write_text(json.dumps(cal, indent=2), encoding="utf-8")
    report = out.with_name("external_calibration_report.md")
    write_report(report, cal)
    print(f"Wrote {out}")
    print(f"Wrote {report}")


if __name__ == "__main__":
    main()
