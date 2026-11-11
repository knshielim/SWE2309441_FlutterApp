# HavaPaw: Text to Add to the FYP Report

Report-ready text for the items the report is missing. Each section says where it goes. Edit the wording
to match your report's style, and renumber figures and tables to fit your chapters.

---

## 3.6 / 5.3: Model selection and comparison

**Goes in 3.6 (method) and 5.3 (results).**

To justify the choice of classifier, five models were compared on the same dataset (20,000 readings from
500 simulated pets) using the same grouped 5-fold cross-validation. Readings were grouped by pet, so every
pet was tested by a model that had never seen it. A majority-class baseline, which always predicts the most
common class (resting), was included to show how much of the accuracy comes from class imbalance alone.

**Table X. Model comparison (grouped 5-fold cross-validation, simulated data)**

| Model | Accuracy | Macro F1 | Recall: resting | Recall: active | Recall: stressed | Recall: anomaly |
|---|---|---|---|---|---|---|
| Baseline (majority class) | 39.34 % | 0.141 | 1.000 | 0.000 | 0.000 | 0.000 |
| Logistic Regression | 95.73 % | 0.929 | 1.000 | 1.000 | 0.908 | 0.810 |
| Decision Tree | 97.33 % | 0.956 | 0.998 | 1.000 | 0.937 | 0.891 |
| **Random Forest** | **98.05 %** | **0.968** | 1.000 | 1.000 | 0.968 | 0.904 |
| SVM (RBF kernel) | 97.69 % | 0.962 | 1.000 | 1.000 | 0.972 | 0.875 |

Macro F1 was used as the main selection criterion because it weights each class equally. This matters
because the clinically important classes (stressed and anomaly) are the smallest. The Random Forest
achieved the highest macro F1 (0.968) and the best anomaly recall (0.904). It was selected for four further
reasons:
1. It handles features on very different scales (heart rate in bpm, temperature in °C, a 0/1 species flag)
   without normalisation.
2. Averaging 200 trees reduces overfitting compared with a single decision tree.
3. It provides feature importances, which supports explaining alerts to owners.
4. Prediction is fast enough to run in real time on a phone after distillation to TensorFlow Lite.

**Hyperparameter tuning.** Six Random Forest settings were compared with the same cross-validation
(n_estimators ∈ {100, 200}, max_depth ∈ {6, 12, unlimited}). Unlimited depth gave a marginal gain (98.22 %,
macro F1 0.971), but max_depth = 12 with 200 trees (98.05 %, 0.968) was kept as a more conservative setting
that is less likely to memorise the synthetic data.

**Final model results (5.3).** On 4,000 readings from held-out test pets, which were never used in
cross-validation, the Random Forest reached **97.78 %** accuracy (macro F1 0.963). Cross-validation on the
training pets gave 98.17 %. Most errors were anomaly readings predicted as stressed (68 of 610), which is
expected because both classes involve an elevated heart rate. The most important features were steps
(0.261), activity ratio vs the 3-day average (0.234) and heart-rate deviation from the pet's personal
baseline (0.155). This shows that the personalised features carry much of the model's decision.

**Data-reduction check.** Two feature pairs were highly correlated (|r| ≥ 0.8): temperature and
temperature deviation (r = 0.90), and heart rate and species (r = −0.83). Both were kept: temperature
deviation is personalised (relative to each pet's limit), and the species correlation reflects real
physiology (cats have higher heart rates).

**Limitation.** All of these results come from simulated data calibrated with real public datasets. They
show that the pipeline and features work. They are not a measure of real-world accuracy, which will be
assessed with labelled readings from the household tests.

**Figures to include (from `havapaw_ml/reports/figures/`):**
- `model_comparison.png`: accuracy and macro F1 for the five models (put in 5.3).
- `confusion_matrix.png`: Random Forest on the unseen test pets (5.3).
- `feature_importance.png`: Random Forest feature importance (5.3).
- `class_distribution.png`: readings per class and species (3.x dataset section).
- `feature_boxplots.png`: key feature values by class (3.x dataset section).
- `correlation_heatmap.png`: correlation between the 11 features (3.x data-reduction section).

---

## 4.6.5: Additional app features

**Goes in 4.6.5.** Shows the scope of the implementation beyond live monitoring.

**Spike check-in.** When a recent reading shows a spike (heart rate above the pet's limit or at least 35 %
above its personal baseline, or temperature above its limit), the Health screen asks the owner what the pet
is doing: playing/running, resting/sleeping, scared/stressed, just ate, or not sure. The app then gives
advice that fits the answer. For example, a raised heart rate during play is normal, while a spike at rest
is treated as more serious. The answer is saved to the health journal and attached to the reading. This
turns an alarm into a short interaction, reduces false alarms caused by exercise, and produces labelled
real data for evaluating the model (playing → active, stressed → stressed).

**Collar-off detection.** If the temperature probe reads below 32 °C, it is measuring room air, so the
collar is assumed not to be on the pet. The app shows a "collar may not be on [pet]" banner and pauses
alerts. The server ignores these readings for alerts, activity and heart-rate baselines, so that a collar
left on a table cannot cause false alerts or distort the pet's baseline.

**"Why this status?" explanations.** Each reading can be expanded to show how every measurement compares
with the pet's own baseline or limit (for example, "Heart rate 100 bpm, +43 % vs Bobby's normal of
70 bpm"), together with the machine-learning prediction and its confidence. This makes alerts explainable
and builds owner trust.

**Activity goal and streak.** A daily goal of active minutes is set from the pet's species, size and age:
20 minutes for cats, 40 for dogs under 12 kg, 60 for 12–55 kg, 45 for dogs over 55 kg, and at most 30 for
puppies and seniors. A progress ring shows today's progress, and a streak counts consecutive days on which
the goal was met. A reading counts as active when the collar records more than 150 steps in the previous
five minutes. Each reading represents 30 seconds, matching the collar's upload interval.

**Walk weather.** The app fetches the current temperature, humidity and "feels like" temperature from the
free Open-Meteo API, using the pet's GPS position or the phone's location. It shows one of four levels:
good, warm, hot (short walks only) or too hot. Flat-faced breeds (e.g. pug, bulldog, Persian) and senior
pets are moved up one level because they are more vulnerable to heatstroke. This feature is particularly
relevant to Malaysia's hot and humid climate.

**Health journal and weekly summary.** Each pet has a journal that combines alerts, check-ins, owner notes
(vet visit, vaccination, ate less, vomited, new food, other) and weight logs on one timeline. A weekly
summary card compares this week with last week: resting heart rate, activity change, and the numbers of
alerts, check-ins and notes. Logged weights are shown as a chart and also update the pet's profile, which
feeds the baseline calculation. These features address the reflective level of Norman's emotional design
by letting owners look back on their pet's health over time.

**30-day vet report (PDF).** One button creates a PDF covering the last 30 days: pet details, daily
resting heart rate and active minutes, alerts, check-ins and notes, weight and medications. The report
can be shared or printed, so owners can bring objective data to a vet visit.

**Medication tracking.** Owners can record each pet's medications (name, dosage, frequency, start and end
date, active or stopped). The list is shown on the Health screen and included in the vet report.
Notification settings include a medication-reminder preference.

**Calming music.** The app includes calming music tracks that the owner can play, for example when the pet
is stressed. The stressed check-in advice points owners to this feature.

**Virtual Vet with history.** In addition to the latest reading and the ML prediction, the Virtual Vet
(GPT-4o) now receives the past week's summary and journal entries. Its advice can therefore take recent
events into account, for example "since Bobby vomited yesterday…". Owner-written text is clipped and
marked as information rather than instructions, to protect against prompt injection.

---

## 4.x / 5.x: Daily summary notification (`dailyDigest`)

**Goes in the backend implementation section (Cloud Functions) and the notification design.**

A scheduled Cloud Function, `dailyDigest`, runs every day at 8 pm Malaysia time (Cloud Scheduler). For
each pet with collar data that day, it sends the owner one push notification summarising the day, for
example: "Bobby's day: 45 of 60 active minutes, resting heart rate 72 bpm, normal for Bobby, no alerts."
The resting heart rate is compared with the previous three days: within ±10 % is described as normal.
Unlike alerts, the digest is not saved to the alert history. Owners can turn it off with the
**Daily summary** switch in Notification settings, which is stored with the other alert preferences
(`alertPrefs.digest`) so the server respects it.

The digest supports the behavioural level of the design: it gives owners regular, low-effort reassurance
and encourages continued use, not only contact when something is wrong.

---

## 3.9 / 5.2.2: Testing tools and end-to-end testing

**Goes in 3.9 (test strategy) and 5.2.2 (integration / end-to-end testing).**

**Virtual collar (`tools/virtual_collar.py`).** To test the complete system repeatably, a virtual collar
was developed. It behaves exactly like the real collar: it uses the same HTTPS endpoint
(`ingestCollarData`), the same per-device token header and the same JSON format. It generates readings
with the same pet physiology used to build the training data. It has four commands:
- `setup` pairs a simulated collar with a real pet in the app.
- `seed` adds three normal days of history, so that baselines and 3-day averages are available at once.
- `run` sends live readings, and the tester can switch the pet's state by typing `resting`, `active`,
  `stressed`, `deviation`, `anomaly fever|hypoxia|tachycardia|dehydration`, `battery N`, `outside` or `home`.
- `dataset` writes simulated readings to CSV and shows how the Random Forest classifies them.

This allowed every alert path to be triggered on demand and checked end to end: high heart rate, stress,
fever, baseline deviation with the GPT-4o note, low battery, leaving the safe zone, and the daily summary.
For each, the test checked collar upload → validation → Firestore → Cloud Function → push notification →
app display. It also allowed controlled demonstrations without depending on the pet's real state.

**Automated tests.**

| Level | Tool | Count | Scope |
|---|---|---|---|
| Unit (app) | `flutter test` | 80 | health rules, baselines, daily summaries, ML feature vector, check-ins, journal, weekly summary, explanations, goals, heat risk, collar-off, PDF report |
| Unit (server) | `node --test` | 15 | thresholds, alerts, deviation, daily summaries, collar-off, activity goal, digest text, Virtual Vet context |
| End to end | virtual collar | all alert types | full data path to push notification |
| Field | real collar on household pets | see test plan | real readings over Wi-Fi |

The real collar is used for the household field tests. Readings are uploaded over Wi-Fi every 30 seconds
after Bluetooth provisioning from the app.

---

## Smaller items

**Firmware build settings (Chapter 4, firmware).** The firmware is built in the Arduino IDE with the ESP32
Arduino core 3.x, board "ESP32 Dev Module". Because the sketch includes the Bluetooth stack, Wi-Fi, TLS and
the sensor libraries (about 1 MB), the **Huge APP** partition scheme (3 MB app space, no OTA) is required;
the default partition is too small. To limit current spikes, the CPU runs at 80 MHz and Bluetooth and Wi-Fi
transmit power are reduced. The collar is powered from the LiPo through a 3.3 V regulator to the ESP32's
3V3 pin.

**Cloud Function regions (Chapter 4, backend).** `ingestCollarData`, `generateVirtualVetAdvice` and
`dailyDigest` run in `us-central1`. `onCollarReading` runs in `asia-southeast1` (Singapore) because a
Firestore-triggered function must be in the same region as the database. All functions run on Node.js 22
(2nd generation Cloud Functions).

**Language of server notifications (limitations).** The app interface is available in English, Bahasa
Melayu, Bahasa Indonesia and Simplified Chinese. Push notifications and GPT-4o notes generated on the
server are currently in English only.

**Active-minutes assumption (limitations).** Active minutes are calculated as the number of active
readings × 0.5 minutes, which assumes the collar uploads every 30 seconds without gaps. Missed uploads
(e.g. weak Wi-Fi) lead to an underestimate.

**Pet photos (data design / privacy).** Pet photos are resized and stored as small base64 images in the
pet's Firestore document, not as uploaded files. This keeps all data under the same owner-only security
rules and avoids a separate storage service. The app does not support uploading pet documents. The health
journal and the vet report cover record-keeping instead.

---

## Household test plan: one prerequisite

Before the household visits, check that the collar runs reliably on battery over Wi-Fi: pair it from the
app, and confirm readings arrive every 30 seconds for at least 30 minutes without resets. The collar must
be powered through the 3.3 V regulator (TPS63020) to the 3V3 pin. Earlier wiring fed the battery into VIN,
which could not supply the radio reliably.
