# Model comparison: baseline, Logistic Regression, Decision Tree, Random Forest, SVM
import time

import numpy as np
import pandas as pd
from sklearn.dummy import DummyClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score, recall_score
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC
from sklearn.tree import DecisionTreeClassifier

from train_random_forest import FEATURE_COLUMNS, LABEL_IDS, LABEL_NAMES, ROOT, load_data

REPORT_PATH = ROOT / "reports" / "model_comparison.md"
RESULTS_PATH = ROOT / "reports" / "model_comparison.csv"

# Logistic Regression and SVM need scaled features; the tree models do not
MODELS = {
    "Baseline (majority class)": DummyClassifier(strategy="most_frequent"),
    "Logistic Regression": make_pipeline(StandardScaler(), LogisticRegression(max_iter=2000)),
    "Decision Tree": DecisionTreeClassifier(max_depth=12, min_samples_leaf=3, random_state=42),
    "Random Forest": RandomForestClassifier(n_estimators=200, max_depth=12, min_samples_leaf=3,
                                            class_weight="balanced", random_state=42, n_jobs=-1),
    "SVM (RBF)": make_pipeline(StandardScaler(), SVC(kernel="rbf", C=1.0, gamma="scale")),
}

# Random Forest settings to try
RF_GRID = [
    {"n_estimators": n, "max_depth": d}
    for n in (100, 200)
    for d in (6, 12, None)
]


def grouped_cv(model, X, y, groups):
    # 5-fold cross-validation where each pet is only in one fold
    cv = StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=42)
    preds = np.empty(len(y), dtype=int)
    for train_idx, test_idx in cv.split(X, y, groups):
        model.fit(X.iloc[train_idx], y.iloc[train_idx])
        preds[test_idx] = model.predict(X.iloc[test_idx])
    return preds


def scores(y, preds):
    recall = recall_score(y, preds, labels=LABEL_IDS, average=None, zero_division=0)
    return {
        "accuracy": accuracy_score(y, preds),
        "macro_f1": f1_score(y, preds, average="macro", zero_division=0),
        **{f"recall_{name}": r for name, r in zip(LABEL_NAMES, recall)},
    }


def main():
    df, _ = load_data()
    X, y, groups = df[FEATURE_COLUMNS], df["label"], df["pet_id"]

    # Model comparison
    rows = []
    for name, model in MODELS.items():
        start = time.time()
        preds = grouped_cv(model, X, y, groups)
        rows.append({"model": name, **scores(y, preds), "seconds": time.time() - start})
        print(f"{name:28s} accuracy {rows[-1]['accuracy']*100:6.2f}%  macro F1 {rows[-1]['macro_f1']:.3f}")
    results = pd.DataFrame(rows)
    results.to_csv(RESULTS_PATH, index=False)

    # Random Forest tuning
    tuning = []
    for params in RF_GRID:
        model = RandomForestClassifier(min_samples_leaf=3, class_weight="balanced",
                                       random_state=42, n_jobs=-1, **params)
        s = scores(y, grouped_cv(model, X, y, groups))
        tuning.append({**params, "accuracy": s["accuracy"], "macro_f1": s["macro_f1"]})
        print(f"RF {params}: accuracy {s['accuracy']*100:.2f}%")
    tuning = pd.DataFrame(tuning)

    # Highly correlated feature pairs (data reduction check)
    corr = df[FEATURE_COLUMNS].corr()
    pairs = [(a, b, corr.loc[a, b]) for i, a in enumerate(FEATURE_COLUMNS)
             for b in FEATURE_COLUMNS[i + 1:] if abs(corr.loc[a, b]) >= 0.8]

    baseline = results.iloc[0]["accuracy"]
    best = results.iloc[1:].sort_values("macro_f1", ascending=False).iloc[0]
    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        f.write("# Model Comparison\n\n")
        f.write(f"Dataset: {len(df)} simulated readings from {df['pet_id'].nunique()} pets. "
                "Every model uses the same 5-fold cross-validation, grouped by pet, so each pet is "
                "tested by a model that never saw it.\n\n")
        f.write("| Model | Accuracy | Macro F1 | Recall resting | Recall active | Recall stressed | "
                "Recall anomaly | Time (s) |\n|---|---|---|---|---|---|---|---|\n")
        for _, r in results.iterrows():
            f.write(f"| {r['model']} | {r['accuracy']*100:.2f}% | {r['macro_f1']:.3f} | "
                    f"{r['recall_resting']:.3f} | {r['recall_active']:.3f} | {r['recall_stressed']:.3f} | "
                    f"{r['recall_anomaly']:.3f} | {r['seconds']:.1f} |\n")
        f.write(f"\nThe baseline always predicts the most common class (resting) and still scores "
                f"{baseline*100:.2f}%, so accuracy alone can look better than it is; macro F1 and the "
                f"per-class recall show how each class is handled.\n\n")
        f.write(f"Best macro F1: **{best['model']}** ({best['macro_f1']:.3f}).\n\n")
        f.write("## Random Forest tuning (same cross-validation)\n\n"
                "| n_estimators | max_depth | Accuracy | Macro F1 |\n|---|---|---|---|\n")
        for _, r in tuning.iterrows():
            depth = "None" if pd.isna(r["max_depth"]) else int(r["max_depth"])
            f.write(f"| {int(r['n_estimators'])} | {depth} | {r['accuracy']*100:.2f}% | {r['macro_f1']:.3f} |\n")
        f.write("\nThe app's model uses n_estimators=200, max_depth=12 (train_random_forest.py).\n\n")
        f.write("## Highly correlated features (|r| >= 0.8)\n\n")
        if pairs:
            for a, b, r in pairs:
                f.write(f"- {a} and {b}: r = {r:.2f}\n")
        else:
            f.write("- none\n")
        f.write("\nAll results are on simulated data.\n")
    print(f"Report saved to {REPORT_PATH}")


if __name__ == "__main__":
    main()
