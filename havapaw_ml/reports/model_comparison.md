# Model Comparison

Dataset: 20000 simulated readings from 500 pets. Every model uses the same 5-fold cross-validation, grouped by pet, so each pet is tested by a model that never saw it.

| Model | Accuracy | Macro F1 | Recall resting | Recall active | Recall stressed | Recall anomaly | Time (s) |
|---|---|---|---|---|---|---|---|
| Baseline (majority class) | 39.34% | 0.141 | 1.000 | 0.000 | 0.000 | 0.000 | 0.1 |
| Logistic Regression | 95.73% | 0.929 | 1.000 | 1.000 | 0.908 | 0.810 | 1.1 |
| Decision Tree | 97.33% | 0.956 | 0.998 | 1.000 | 0.937 | 0.891 | 0.3 |
| Random Forest | 98.05% | 0.968 | 1.000 | 1.000 | 0.968 | 0.904 | 4.0 |
| SVM (RBF) | 97.69% | 0.962 | 1.000 | 1.000 | 0.972 | 0.875 | 2.3 |

The baseline always predicts the most common class (resting) and still scores 39.34%, so accuracy alone can look better than it is; macro F1 and the per-class recall show how each class is handled.

Best macro F1: **Random Forest** (0.968).

## Random Forest tuning (same cross-validation)

| n_estimators | max_depth | Accuracy | Macro F1 |
|---|---|---|---|
| 100 | 6 | 97.15% | 0.952 |
| 100 | 12 | 98.06% | 0.968 |
| 100 | None | 98.22% | 0.970 |
| 200 | 6 | 97.21% | 0.953 |
| 200 | 12 | 98.05% | 0.968 |
| 200 | None | 98.22% | 0.971 |

The app's model uses n_estimators=200, max_depth=12 (train_random_forest.py).

## Highly correlated features (|r| >= 0.8)

- heart_rate and species_encoded: r = -0.83
- temperature and temp_deviation_c: r = 0.90

All results are on simulated data.
