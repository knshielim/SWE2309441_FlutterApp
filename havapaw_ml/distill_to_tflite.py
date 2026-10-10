"""
Knowledge-distills the trained Random Forest into a small feed-forward network,
then converts that network to a genuine, standard-ops TFLite model for on-device
inference in the Flutter app.

WHY: tf.lite.TFLiteConverter cannot export a native RandomForest (sklearn or
tensorflow_decision_forests) using standard TFLite ops -- both rely on custom
SimpleML ops with no mobile-runtime support (see ERROR_NEEDS_CUSTOM_OPS). Model
distillation -- training a small NN to reproduce a larger/more complex model's
output distribution -- is a standard, documented technique (Hinton et al., 2015)
and is what makes "Random Forest classifier ... converted into TensorFlow Lite
format" (proposal Figure 3) actually work on a phone.

The Random Forest remains the model that is trained and evaluated for the FYP
report's accuracy figures; the distilled network is only the deployment artifact.

CHANGES FROM THE ORIGINAL: paths are relative to this file, and the optional
--copy-to-app flag copies the new model and metadata into the Flutter app's
assets so you cannot forget a file.

USAGE (from the havapaw_ml folder; needs tensorflow installed):
    python distill_to_tflite.py
    python distill_to_tflite.py --copy-to-app
"""

import argparse
import json
import shutil
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parent
MODEL_PATH = ROOT / "models" / "random_forest_model.joblib"
STATS_PATH = ROOT / "models" / "feature_stats.json"
DATA_PATH = ROOT / "data" / "pet_health_dataset.csv"
TFLITE_PATH = ROOT / "models" / "pet_health_classifier.tflite"
LABELS_PATH = ROOT / "models" / "labels.json"
APP_ASSETS = ROOT.parent / "havapaw" / "assets" / "ml"

parser = argparse.ArgumentParser()
parser.add_argument("--copy-to-app", action="store_true",
                    help="copy the .tflite and metadata into havapaw/assets/ml/")
args = parser.parse_args()

bundle = joblib.load(MODEL_PATH)
rf = bundle["model"]
species_encoder = bundle["species_encoder"]
feature_columns = bundle["feature_columns"]
label_names = bundle["label_names"]

with open(STATS_PATH) as f:
    stats = json.load(f)
mean = np.array([stats["mean"][c] for c in feature_columns], dtype=np.float32)
std = np.array([stats["std"][c] for c in feature_columns], dtype=np.float32)
std[std == 0] = 1.0

df = pd.read_csv(DATA_PATH)
df["species_encoded"] = species_encoder.transform(df["species"])
X = df[feature_columns].values.astype(np.float32)

# Soft labels from the Random Forest -- this is the distillation target
soft_labels = rf.predict_proba(X)

X_norm = (X - mean) / std
X_train, X_val, y_train, y_val = train_test_split(
    X_norm, soft_labels, test_size=0.15, random_state=42
)

student = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(len(feature_columns),)),
    tf.keras.layers.Dense(32, activation="relu"),
    tf.keras.layers.Dense(16, activation="relu"),
    tf.keras.layers.Dense(len(label_names), activation="softmax"),
])
student.compile(optimizer="adam", loss="categorical_crossentropy", metrics=["accuracy"])

history = student.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=40, batch_size=64, verbose=0,
)

# Agreement between distilled network and the Random Forest's hard predictions
rf_hard = rf.predict(X)
student_hard = np.argmax(student.predict(X_norm, verbose=0), axis=1)
agreement = float(np.mean(rf_hard == student_hard))
print(f"Distilled network agrees with Random Forest on {agreement*100:.2f}% of samples")

converter = tf.lite.TFLiteConverter.from_keras_model(student)
tflite_model = converter.convert()
with open(TFLITE_PATH, "wb") as f:
    f.write(tflite_model)
print(f"TFLite model written to {TFLITE_PATH} ({len(tflite_model)/1024:.1f} KB)")

with open(LABELS_PATH, "w") as f:
    json.dump({
        "feature_columns": feature_columns,
        "label_names": label_names,
        "normalization_mean": mean.tolist(),
        "normalization_std": std.tolist(),
        "distillation_agreement_with_rf": agreement,
    }, f, indent=2)
print(f"Metadata written to {LABELS_PATH}")

if args.copy_to_app:
    APP_ASSETS.mkdir(parents=True, exist_ok=True)
    shutil.copy(TFLITE_PATH, APP_ASSETS / "pet_health_classifier.tflite")
    shutil.copy(LABELS_PATH, APP_ASSETS / "model_metadata.json")
    print(f"Copied model and metadata to {APP_ASSETS}")
