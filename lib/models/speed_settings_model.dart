import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';

enum SpeedDisplayUnit { kmh, mps, pace500m }

class SpeedSettingsModel extends ChangeNotifier {
  SpeedDisplayUnit _displayUnit = SpeedDisplayUnit.kmh;

  SpeedDisplayUnit get displayUnit => _displayUnit;

  Unit get unit => switch (_displayUnit) {
    SpeedDisplayUnit.kmh => Unit.kmh,
    SpeedDisplayUnit.mps => Unit.mps,
    SpeedDisplayUnit.pace500m => Unit.pace,
  };

  void setDisplayUnit(SpeedDisplayUnit value) {
    if (_displayUnit == value) return;
    _displayUnit = value;
    notifyListeners();
  }

  double convertFromMps(double metersPerSecond) => switch (_displayUnit) {
    SpeedDisplayUnit.kmh => metersPerSecond * 3.6,
    SpeedDisplayUnit.mps => metersPerSecond,
    SpeedDisplayUnit.pace500m =>
      metersPerSecond > 0 ? 500.0 / metersPerSecond : double.nan,
  };
}
