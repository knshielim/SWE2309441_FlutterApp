# HavaPaw Random Forest Health Classifier - Evaluation Report

Dataset: 20000 readings from 500 simulated pet profiles.

**Important:** the figures below are internal validation on simulated data. They show that the pipeline works; they are not evidence of real-world accuracy, and should not be compared directly with accuracies measured on real sensor data.

## Data sources

- activity_index (cat) drawn from real accelerometer data: 1,331,811 resting and 445,588 active samples
- activity_index (dog) drawn from real accelerometer data: 198,868 resting and 145,489 active samples
- dog resting heart-rate baselines from 40 real dogs (Invoxia): small 59.7, medium 59.7, large 52.4, toy 59.7, giant 52.4 bpm; no toy or giant dogs in that data, so toy uses small and giant uses large
- heart-rate thresholds checked against ECG recordings of 4 dogs (Zenodo 19383015); not used for training
- cat heart rate, steps, SpO2, temperature and the stressed/anomaly classes remain synthetic

## Splitting

All splits are grouped by pet: every pet's readings are entirely in the training data or entirely in the test data.

## 5-Fold Grouped Cross-Validation (training pets, n=16000 readings)

**Cross-validated accuracy: 98.17%**

```
              precision    recall  f1-score   support

     resting     0.9989    1.0000    0.9994      6300
      active     1.0000    0.9998    0.9999      4898
    stressed     0.9140    0.9695    0.9409      2357
     anomaly     0.9691    0.9100    0.9386      2445

    accuracy                         0.9817     16000
   macro avg     0.9705    0.9698    0.9697     16000
weighted avg     0.9822    0.9817    0.9817     16000

```

## Held-out Test Pets (n=4000 readings, never seen during CV)

**Test accuracy: 97.78%**

By species: cat 98.05%, dog 97.58%

```
              precision    recall  f1-score   support

     resting     0.9994    1.0000    0.9997      1569
      active     1.0000    1.0000    1.0000      1233
    stressed     0.8931    0.9660    0.9281       588
     anomaly     0.9643    0.8869    0.9240       610

    accuracy                         0.9778      4000
   macro avg     0.9642    0.9632    0.9629      4000
weighted avg     0.9786    0.9778    0.9777      4000

```

## Confusion Matrix (rows=actual, cols=predicted)

| | resting | active | stressed | anomaly |
|---|---|---|---|---|
| **resting** | 1569 | 0 | 0 | 0 |
| **active** | 0 | 1233 | 0 | 0 |
| **stressed** | 0 | 0 | 568 | 20 |
| **anomaly** | 1 | 0 | 68 | 541 |

## Feature Importance

| Feature | Importance |
|---|---|
| steps | 0.2608 |
| activity_ratio_3day | 0.2339 |
| hr_deviation_pct | 0.1550 |
| temp_deviation_c | 0.1019 |
| temperature | 0.0763 |
| heart_rate | 0.0712 |
| spo2 | 0.0699 |
| activity_index | 0.0209 |
| species_encoded | 0.0045 |
| weight | 0.0028 |
| age | 0.0027 |

## Limitations

- activity_index (the only real accelerometer feature) has an importance of only 0.02. The calibration found that a single accelerometer sample separates resting from active poorly, so the model relies on steps and activity_ratio_3day, which are synthetic. A windowed feature (e.g. the spread of activity_index over a few seconds), computed both from the public data and in the firmware, would be needed to change this.
- stressed and anomaly can only be checked on simulated data: they cannot be ethically provoked in real pets.
- No real-pet evaluation yet: run with --real-csv (and --mix-real) once labelled collar readings are available.
