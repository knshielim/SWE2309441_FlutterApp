# Report figures for the dataset and the Random Forest
import joblib
import matplotlib
import pandas as pd

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import seaborn as sns  # noqa: E402
from sklearn.metrics import confusion_matrix  # noqa: E402
from sklearn.model_selection import StratifiedGroupKFold  # noqa: E402

from train_random_forest import FEATURE_COLUMNS, LABEL_IDS, LABEL_NAMES, MODEL_PATH, ROOT, load_data  # noqa: E402

FIG_DIR = ROOT / "reports" / "figures"
COMPARISON_PATH = ROOT / "reports" / "model_comparison.csv"
ORDER = LABEL_NAMES


def save(fig, name):
    fig.tight_layout()
    fig.savefig(FIG_DIR / name, dpi=200)
    plt.close(fig)
    print(f"Saved {FIG_DIR / name}")


def main():
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    sns.set_theme(style="whitegrid")
    df, _ = load_data()

    # 1. Class distribution
    fig, ax = plt.subplots(figsize=(6, 4))
    sns.countplot(data=df, x="label_name", hue="species", order=ORDER, ax=ax)
    ax.set(title="Readings per class and species", xlabel="Class", ylabel="Readings")
    save(fig, "class_distribution.png")

    # 2. Key features by class
    features = [("hr_deviation_pct", "Heart rate vs pet's normal (%)"),
                ("steps", "Steps (last 5 min)"),
                ("activity_ratio_3day", "Activity vs 3-day average"),
                ("temp_deviation_c", "Temperature vs fever limit (°C)"),
                ("spo2", "SpO2 (%)"),
                ("activity_index", "Activity index (g²)")]
    fig, axes = plt.subplots(2, 3, figsize=(13, 7))
    for ax, (col, title) in zip(axes.flat, features):
        sns.boxplot(data=df, x="label_name", y=col, order=ORDER, ax=ax, showfliers=False)
        ax.set(title=title, xlabel="", ylabel="")
    fig.suptitle("Feature values by class")
    save(fig, "feature_boxplots.png")

    # 3. Correlation heatmap
    fig, ax = plt.subplots(figsize=(9, 7))
    sns.heatmap(df[FEATURE_COLUMNS].corr(), annot=True, fmt=".2f", cmap="coolwarm",
                vmin=-1, vmax=1, ax=ax)
    ax.set_title("Correlation between features")
    save(fig, "correlation_heatmap.png")

    # 4. Confusion matrix on the held-out test pets (same split as train_random_forest.py)
    X, y, groups = df[FEATURE_COLUMNS], df["label"], df["pet_id"]
    splitter = StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=42)
    _, test_idx = next(splitter.split(X, y, groups))
    model = joblib.load(MODEL_PATH)["model"]
    cm = confusion_matrix(y.iloc[test_idx], model.predict(X.iloc[test_idx]), labels=LABEL_IDS)
    fig, ax = plt.subplots(figsize=(6, 5))
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", xticklabels=ORDER, yticklabels=ORDER, ax=ax)
    ax.set(title="Confusion matrix (unseen test pets)", xlabel="Predicted", ylabel="Actual")
    save(fig, "confusion_matrix.png")

    # 5. Feature importance
    importance = pd.Series(model.feature_importances_, index=FEATURE_COLUMNS).sort_values()
    fig, ax = plt.subplots(figsize=(7, 5))
    importance.plot.barh(ax=ax, color="#2a9d8f")
    ax.set(title="Random Forest feature importance", xlabel="Importance")
    save(fig, "feature_importance.png")

    # 6. Model comparison (from compare_models.py)
    if COMPARISON_PATH.exists():
        results = pd.read_csv(COMPARISON_PATH)
        long = results.melt(id_vars="model", value_vars=["accuracy", "macro_f1"],
                            var_name="metric", value_name="score")
        long["metric"] = long["metric"].map({"accuracy": "Accuracy", "macro_f1": "Macro F1"})
        fig, ax = plt.subplots(figsize=(9, 4.5))
        sns.barplot(data=long, x="model", y="score", hue="metric", ax=ax)
        ax.set(title="Model comparison (grouped 5-fold cross-validation)", xlabel="", ylabel="Score",
               ylim=(0, 1.05))
        ax.tick_params(axis="x", rotation=15)
        for container in ax.containers:
            ax.bar_label(container, fmt="%.2f", fontsize=8)
        save(fig, "model_comparison.png")
    else:
        print("Run compare_models.py first for the model comparison chart.")


if __name__ == "__main__":
    main()
