# HavaPaw Random Forest Health Classifier - Evaluation Report

Dataset: 20000 readings from 500 simulated pet profiles.

**Important:** the figures below are internal validation on simulated data. They show that the pipeline works; they are not evidence of real-world accuracy, and should not be compared directly with accuracies measured on real sensor data.

## Data sources

- activity_index (cat) drawn from real accelerometer data: 1,331,811 resting and 445,588 active samples
- activity_index (dog) drawn from real accelerometer data: 198,868 resting and 145,489 active samples
- dog resting heart rate compared with 40 real dogs (Invoxia); see external/external_calibration_report.md
- steps, SpO2, temperature and the stressed/anomaly classes remain synthetic

## Splitting

All splits are grouped by pet: every pet's readings are entirely in the training data or entirely in the test data.

## 5-Fold Grouped Cross-Validation (training pets, n=16000 readings)

**Cross-validated accuracy: 98.06%**

```
              precision    recall  f1-score   support

     resting     0.9984    0.9989    0.9987      6341
      active     1.0000    0.9998    0.9999      4832
    stressed     0.9087    0.9715    0.9390      2418
     anomaly     0.9710    0.9029    0.9357      2409

    accuracy                         0.9806     16000
   macro avg     0.9695    0.9683    0.9683     16000
weighted avg     0.9812    0.9806    0.9805     16000

```

## Held-out Test Pets (n=4000 readings, never seen during CV)

**Test accuracy: 97.45%**

By species: cat 97.55%, dog 97.36%

```
              precision    recall  f1-score   support

     resting     0.9988    0.9994    0.9991      1605
      active     1.0000    0.9992    0.9996      1196
    stressed     0.8880    0.9554    0.9205       606
     anomaly     0.9506    0.8769    0.9123       593

    accuracy                         0.9745      4000
   macro avg     0.9594    0.9577    0.9579      4000
weighted avg     0.9752    0.9745    0.9745      4000

```

## Confusion Matrix (rows=actual, cols=predicted)

| | resting | active | stressed | anomaly |
|---|---|---|---|---|
| **resting** | 1604 | 0 | 1 | 0 |
| **active** | 0 | 1195 | 0 | 1 |
| **stressed** | 1 | 0 | 579 | 26 |
| **anomaly** | 1 | 0 | 72 | 520 |

## Feature Importance

| Feature | Importance |
|---|---|
| steps | 0.2674 |
| activity_ratio_3day | 0.2497 |
| hr_deviation_pct | 0.1509 |
| temp_deviation_c | 0.1052 |
| spo2 | 0.0729 |
| temperature | 0.0716 |
| heart_rate | 0.0504 |
| activity_index | 0.0226 |
| weight | 0.0051 |
| age | 0.0027 |
| species_encoded | 0.0017 |
