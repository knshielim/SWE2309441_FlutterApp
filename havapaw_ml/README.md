# HavaPaw ML

Run from this folder.

## Train and update the app model
```
python data/generate_dataset.py
python train_random_forest.py
python distill_to_tflite.py --copy-to-app
```
Needs `pandas scikit-learn joblib tensorflow`. Results go to `reports/rf_evaluation_report.md`.

## Test on real collar readings
```
python export_collar_readings.py --key <service-account.json> --email <your login> --labels my_labels.csv
python train_random_forest.py --real-csv data/real_readings.csv
python train_random_forest.py --real-csv data/real_readings.csv --mix-real
```
`--mix-real` needs labelled readings from at least 2 pets. It tests each pet with a model trained on
synthetic data only and with one trained on synthetic data plus the other real pets, and adds both
results to the report. `--real-weight` (default 10) sets how much each real reading counts.

## Data sources
- Real dog and cat accelerometer data (Mendeley, Kaggle) for `activity_index`.
- Real dog resting heart rate (Invoxia, 40 dogs) for the dog baselines: small/medium 59.7 bpm,
  large 52.4 bpm. No toy or giant dogs in that data, so toy uses small and giant uses large.
  The app uses the same values (`HealthIntelligenceService.getPopulationRestingHeartRateBaseline`).
- ECG recordings of 4 dogs (Zenodo 19383015) to check thresholds only.
- `external/calibrate_from_external.py` rebuilds `external/external_calibration.json` from the raw files.
