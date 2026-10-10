"""
Trains and evaluates the Random Forest health-state classifier for HavaPaw.

Matches proposal Phase 4 & 6-7:
- Random Forest classifier with individualized (per-pet) baselines
- Evaluation via k-fold cross-validation, target >=95% accuracy
- Feature importance reported for the FYP write-up

CHANGES FROM THE ORIGINAL
- Splits are GROUPED BY PET (pet_id): no pet has readings in both the training and
  test data. The original reading-level split let the same synthetic pet appear on
  both sides, which inflates accuracy.
- Paths are relative to this file, so it runs on any machine.
- The report labels the numbers as internal validation on simulated data.
- Optional: --real-csv evaluates the trained model on REAL labelled readings (for
  example from your own collar) that were never used for training.

USAGE (from the havapaw_ml folder):
    python train_random_forest.py
    python train_random_forest.py --real-csv path/to/real_readings.csv

The real-readings CSV needs these columns (same meaning as the training features):
    species (dog/cat), heart_rate, temperature, spo2, activity_index, steps,
    activity_ratio_3day, hr_deviation_pct, temp_deviation_c, age, weight,
    label (0=resting, 1=active, 2=stressed, 3=anomaly)
"""

import argparse
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import StratifiedGroupKFold, cross_val_predict
from sklearn.preprocessing import LabelEncoder

ROOT = Path(__file__).resolve().parent
DATA_PATH = ROOT / "data" / "pet_health_dataset.csv"
MODEL_PATH = ROOT / "models" / "random_forest_model.joblib"
STATS_PATH = ROOT / "models" / "feature_stats.json"
REPORT_PATH = ROOT / "reports" / "rf_evaluation_report.md"
CALIBRATION_PATH = ROOT / "external" / "external_calibration.json"

FEATURE_COLUMNS = [
    "heart_rate", "temperature", "spo2", "activity_index", "steps",
    "activity_ratio_3day", "hr_deviation_pct", "temp_deviation_c",
    "age", "weight", "species_encoded",
]
LABEL_NAMES = ["resting", "active", "stressed", "anomaly"]
LABEL_IDS = [0, 1, 2, 3]


def load_data():
    df = pd.read_csv(DATA_PATH)
    species_encoder = LabelEncoder()
    df["species_encoded"] = species_encoder.fit_transform(df["species"])  # cat=0, dog=1
    return df, species_encoder


def table(cm):
    lines = ["| | " + " | ".join(LABEL_NAMES) + " |", "|---" * (len(LABEL_NAMES) + 1) + "|"]
    for i, row in enumerate(cm):
        lines.append(f"| **{LABEL_NAMES[i]}** | " + " | ".join(str(v) for v in row) + " |")
    return "\n".join(lines) + "\n"


def calibration_summary():
    if not CALIBRATION_PATH.exists():
        return "No external calibration was loaded: all features are fully synthetic.\n"
    with open(CALIBRATION_PATH, encoding="utf-8") as f:
        cal = json.load(f)
    parts = []
    for species, block in cal.get("activity_index", {}).items():
        s = block["summary"]
        parts.append(f"- activity_index ({species}) drawn from real accelerometer data: "
                     f"{s['resting']['n']:,} resting and {s['active']['n']:,} active samples")
    if "invoxia" in cal:
        parts.append(f"- dog resting heart rate compared with {cal['invoxia']['n_dogs']} real dogs "
                     "(Invoxia); see external/external_calibration_report.md")
    parts.append("- steps, SpO2, temperature and the stressed/anomaly classes remain synthetic")
    return "\n".join(parts) + "\n"


def evaluate_real(clf, species_encoder, csv_path):
    real = pd.read_csv(csv_path)
    real["species_encoded"] = species_encoder.transform(real["species"])
    X, y = real[FEATURE_COLUMNS], real["label"]
    preds = clf.predict(X)
    acc = accuracy_score(y, preds)
    report = classification_report(y, preds, labels=LABEL_IDS, target_names=LABEL_NAMES,
                                   digits=4, zero_division=0)
    cm = confusion_matrix(y, preds, labels=LABEL_IDS)
    return len(real), acc, report, cm


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--real-csv", help="real labelled readings for external validation")
    args = parser.parse_args()

    df, species_encoder = load_data()
    X, y, groups = df[FEATURE_COLUMNS], df["label"], df["pet_id"]

    # Held-out test set grouped by pet: whole pets are unseen at test time.
    splitter = StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=42)
    train_idx, test_idx = next(splitter.split(X, y, groups))
    X_train, X_test = X.iloc[train_idx], X.iloc[test_idx]
    y_train, y_test = y.iloc[train_idx], y.iloc[test_idx]
    g_train = groups.iloc[train_idx]
    species_test = df["species"].iloc[test_idx]
    assert set(groups.iloc[train_idx]).isdisjoint(set(groups.iloc[test_idx])), "pet leaked across split"

    clf = RandomForestClassifier(
        n_estimators=200,
        max_depth=12,
        min_samples_leaf=3,
        class_weight="balanced",
        random_state=42,
        n_jobs=-1,
    )

    # 5-fold cross-validation on the training pets, also grouped by pet
    cv = StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=42)
    cv_preds = cross_val_predict(clf, X_train, y_train, cv=cv, groups=g_train, n_jobs=-1)
    cv_accuracy = accuracy_score(y_train, cv_preds)
    cv_report = classification_report(y_train, cv_preds, target_names=LABEL_NAMES, digits=4)

    clf.fit(X_train, y_train)
    test_preds = clf.predict(X_test)
    test_accuracy = accuracy_score(y_test, test_preds)
    test_report = classification_report(y_test, test_preds, target_names=LABEL_NAMES, digits=4)
    cm = confusion_matrix(y_test, test_preds)
    by_species = {s: accuracy_score(y_test[species_test == s], test_preds[(species_test == s).to_numpy()])
                  for s in sorted(species_test.unique())}

    importances = sorted(zip(FEATURE_COLUMNS, clf.feature_importances_), key=lambda x: -x[1])

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": clf, "species_encoder": species_encoder,
                 "feature_columns": FEATURE_COLUMNS, "label_names": LABEL_NAMES}, MODEL_PATH)

    real_section = ""
    if args.real_csv:
        n_real, real_acc, real_report, real_cm = evaluate_real(clf, species_encoder, args.real_csv)
        real_section = (
            f"\n## External validation on real readings (n={n_real}, never used for training)\n\n"
            f"**Accuracy: {real_acc*100:.2f}%**\n\n```\n{real_report}\n```\n\n"
            "Confusion matrix (rows=actual, cols=predicted)\n\n" + table(real_cm)
        )
        print(f"Real-data accuracy: {real_acc*100:.2f}% (n={n_real})")

    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        f.write("# HavaPaw Random Forest Health Classifier - Evaluation Report\n\n")
        f.write(f"Dataset: {len(df)} readings from {df['pet_id'].nunique()} simulated pet profiles.\n\n")
        f.write("**Important:** the figures below are internal validation on simulated data. "
                "They show that the pipeline works; they are not evidence of real-world accuracy, "
                "and should not be compared directly with accuracies measured on real sensor data.\n\n")
        f.write("## Data sources\n\n" + calibration_summary() + "\n")
        f.write("## Splitting\n\nAll splits are grouped by pet: every pet's readings are entirely in "
                "the training data or entirely in the test data.\n\n")
        f.write(f"## 5-Fold Grouped Cross-Validation (training pets, n={len(X_train)} readings)\n\n")
        f.write(f"**Cross-validated accuracy: {cv_accuracy*100:.2f}%**\n\n")
        f.write("```\n" + cv_report + "\n```\n\n")
        f.write(f"## Held-out Test Pets (n={len(X_test)} readings, never seen during CV)\n\n")
        f.write(f"**Test accuracy: {test_accuracy*100:.2f}%**\n\n")
        f.write("By species: " + ", ".join(f"{s} {a*100:.2f}%" for s, a in by_species.items()) + "\n\n")
        f.write("```\n" + test_report + "\n```\n\n")
        f.write("## Confusion Matrix (rows=actual, cols=predicted)\n\n" + table(cm))
        f.write("\n## Feature Importance\n\n| Feature | Importance |\n|---|---|\n")
        for feat, imp in importances:
            f.write(f"| {feat} | {imp:.4f} |\n")
        f.write(real_section)

    print(f"CV accuracy (grouped): {cv_accuracy*100:.2f}%")
    print(f"Test accuracy (unseen pets): {test_accuracy*100:.2f}%")
    print(f"Model saved to {MODEL_PATH}")
    print(f"Report saved to {REPORT_PATH}")

    # Means/stds used for feature scaling in the distillation step
    stats = {
        "feature_columns": FEATURE_COLUMNS,
        "mean": X_train.mean().to_dict(),
        "std": X_train.std().to_dict(),
    }
    with open(STATS_PATH, "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2)


if __name__ == "__main__":
    main()
