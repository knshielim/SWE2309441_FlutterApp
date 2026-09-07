"""
Trains and evaluates the Random Forest health-state classifier for HavaPaw.

Matches proposal Phase 4 & 6-7:
- Random Forest classifier with individualized (per-pet) baselines
- Evaluation via k-fold cross-validation, target >=95% accuracy
- Feature importance reported for the FYP write-up
"""

import json
import numpy as np
import pandas as pd
import joblib
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import StratifiedKFold, cross_val_predict, train_test_split
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from sklearn.preprocessing import LabelEncoder

DATA_PATH = "/home/claude/havapaw_ml/data/pet_health_dataset.csv"
MODEL_PATH = "/home/claude/havapaw_ml/models/random_forest_model.joblib"
REPORT_PATH = "/home/claude/havapaw_ml/reports/rf_evaluation_report.md"

FEATURE_COLUMNS = [
    "heart_rate", "temperature", "spo2", "activity_index", "steps",
    "activity_ratio_3day", "hr_deviation_pct", "temp_deviation_c",
    "age", "weight", "species_encoded",
]
LABEL_NAMES = ["resting", "active", "stressed", "anomaly"]


def load_data():
    df = pd.read_csv(DATA_PATH)
    species_encoder = LabelEncoder()
    df["species_encoded"] = species_encoder.fit_transform(df["species"])
    return df, species_encoder


def main():
    df, species_encoder = load_data()
    X = df[FEATURE_COLUMNS]
    y = df["label"]

    # Held-out test set (never touched during CV) for a final honest number
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    clf = RandomForestClassifier(
        n_estimators=200,
        max_depth=12,
        min_samples_leaf=3,
        class_weight="balanced",
        random_state=42,
        n_jobs=-1,
    )

    # k-fold cross-validation on the training split (proposal requires k-fold CV)
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    cv_preds = cross_val_predict(clf, X_train, y_train, cv=skf, n_jobs=-1)
    cv_accuracy = accuracy_score(y_train, cv_preds)
    cv_report = classification_report(
        y_train, cv_preds, target_names=LABEL_NAMES, digits=4
    )

    # Fit final model on full training split, evaluate on untouched test split
    clf.fit(X_train, y_train)
    test_preds = clf.predict(X_test)
    test_accuracy = accuracy_score(y_test, test_preds)
    test_report = classification_report(
        y_test, test_preds, target_names=LABEL_NAMES, digits=4
    )
    cm = confusion_matrix(y_test, test_preds)

    importances = sorted(
        zip(FEATURE_COLUMNS, clf.feature_importances_),
        key=lambda x: -x[1],
    )

    joblib.dump({"model": clf, "species_encoder": species_encoder,
                 "feature_columns": FEATURE_COLUMNS, "label_names": LABEL_NAMES}, MODEL_PATH)

    with open(REPORT_PATH, "w") as f:
        f.write("# HavaPaw Random Forest Health Classifier - Evaluation Report\n\n")
        f.write(f"Dataset: {len(df)} readings from {df['pet_id'].nunique()} synthetic pet profiles ")
        f.write("(literature-grounded synthetic data - see data/generate_dataset.py for sourcing)\n\n")
        f.write(f"## 5-Fold Cross-Validation (training split, n={len(X_train)})\n\n")
        f.write(f"**Cross-validated accuracy: {cv_accuracy*100:.2f}%**\n\n")
        f.write("```\n" + cv_report + "\n```\n\n")
        f.write(f"## Held-out Test Set (n={len(X_test)}, never seen during CV)\n\n")
        f.write(f"**Test accuracy: {test_accuracy*100:.2f}%**\n\n")
        f.write("```\n" + test_report + "\n```\n\n")
        f.write("## Confusion Matrix (rows=actual, cols=predicted)\n\n")
        f.write("| | " + " | ".join(LABEL_NAMES) + " |\n")
        f.write("|---" * (len(LABEL_NAMES) + 1) + "|\n")
        for i, row in enumerate(cm):
            f.write(f"| **{LABEL_NAMES[i]}** | " + " | ".join(str(v) for v in row) + " |\n")
        f.write("\n## Feature Importance\n\n")
        f.write("| Feature | Importance |\n|---|---|\n")
        for feat, imp in importances:
            f.write(f"| {feat} | {imp:.4f} |\n")

    print(f"CV accuracy: {cv_accuracy*100:.2f}%")
    print(f"Test accuracy: {test_accuracy*100:.2f}%")
    print(f"Model saved to {MODEL_PATH}")
    print(f"Report saved to {REPORT_PATH}")

    # Export means/stds used for feature scaling reference in the distillation step
    stats = {
        "feature_columns": FEATURE_COLUMNS,
        "mean": X_train.mean().to_dict(),
        "std": X_train.std().to_dict(),
    }
    with open("/home/claude/havapaw_ml/models/feature_stats.json", "w") as f:
        json.dump(stats, f, indent=2)


if __name__ == "__main__":
    main()
