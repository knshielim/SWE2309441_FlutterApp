# HavaPaw Random Forest Health Classifier - Evaluation Report

Dataset: 20000 readings from 500 synthetic pet profiles (literature-grounded synthetic data - see data/generate_dataset.py for sourcing)

## 5-Fold Cross-Validation (training split, n=16000)

**Cross-validated accuracy: 97.88%**

```
              precision    recall  f1-score   support

     resting     0.9988    0.9992    0.9990      6436
      active     1.0000    0.9998    0.9999      4679
    stressed     0.8996    0.9720    0.9344      2462
     anomaly     0.9708    0.8906    0.9290      2423

    accuracy                         0.9788     16000
   macro avg     0.9673    0.9654    0.9656     16000
weighted avg     0.9796    0.9788    0.9787     16000

```

## Held-out Test Set (n=4000, never seen during CV)

**Test accuracy: 97.88%**

```
              precision    recall  f1-score   support

     resting     1.0000    0.9975    0.9988      1609
      active     1.0000    1.0000    1.0000      1170
    stressed     0.8958    0.9773    0.9348       616
     anomaly     0.9729    0.8893    0.9292       605

    accuracy                         0.9788      4000
   macro avg     0.9672    0.9660    0.9657      4000
weighted avg     0.9799    0.9788    0.9787      4000

```

## Confusion Matrix (rows=actual, cols=predicted)

| | resting | active | stressed | anomaly |
|---|---|---|---|---|
| **resting** | 1605 | 0 | 3 | 1 |
| **active** | 0 | 1170 | 0 | 0 |
| **stressed** | 0 | 0 | 602 | 14 |
| **anomaly** | 0 | 0 | 67 | 538 |

## Feature Importance

| Feature | Importance |
|---|---|
| steps | 0.2315 |
| activity_ratio_3day | 0.1992 |
| hr_deviation_pct | 0.1534 |
| activity_index | 0.1207 |
| temp_deviation_c | 0.0909 |
| temperature | 0.0799 |
| spo2 | 0.0689 |
| heart_rate | 0.0469 |
| weight | 0.0045 |
| age | 0.0026 |
| species_encoded | 0.0014 |
