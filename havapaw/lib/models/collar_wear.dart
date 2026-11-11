// Detects when the collar is not on the pet (same rule as rules.js isOffBody)
import 'collar_data.dart';

class CollarWear {
  // Below this the temperature probe is reading room air
  static const double offBodyTempC = 32.0;

  static bool isOffBody(CollarData reading) {
    final t = reading.temperature;
    return t != null && t < offBodyTempC;
  }
}
