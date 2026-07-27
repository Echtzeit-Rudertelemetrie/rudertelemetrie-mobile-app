import 'package:flutter/foundation.dart';

/// Catch/finish threshold mode (stroke-detection §2.1).
enum ThresholdMode { absolute, autoScaled }

/// Crew-level event aggregation across oarlocks (stroke-detection §3).
enum CrewAggregation { max, mean }

/// Tunable stroke-detection parameters (stroke-detection §6), exposed so they
/// can be adjusted without a rebuild. Defaults are the spec starting points.
class StrokeSettings extends ChangeNotifier {
  ThresholdMode _mode = ThresholdMode.absolute;

  /// Absolute thresholds (N).
  double _fOn = 40;
  double _fOff = 20;

  /// Auto-scaled coefficients on the recent peak force.
  final double _kOn = 0.15;
  final double _kOff = 0.08;

  /// Minimum drive duration and stroke period (s) — reject spikes/impossibly
  /// fast strokes.
  final double _tauMinDrive = 0.2;
  final double _tauMinStroke = 0.7;

  /// Not-rowing timeout (s).
  final double _idleTimeout = 5;

  CrewAggregation _crewAggregation = CrewAggregation.max;

  /// Angle low-pass cutoff before differentiation (Hz), fixed for fs = 100 Hz.
  static const double angleLpfCutoffHz = 4;

  ThresholdMode get mode => _mode;
  double get fOn => _fOn;
  double get fOff => _fOff;
  double get kOn => _kOn;
  double get kOff => _kOff;
  double get tauMinDrive => _tauMinDrive;
  double get tauMinStroke => _tauMinStroke;
  double get idleTimeout => _idleTimeout;
  CrewAggregation get crewAggregation => _crewAggregation;

  void setMode(ThresholdMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  void setAbsoluteThresholds({double? fOn, double? fOff}) {
    _fOn = fOn ?? _fOn;
    _fOff = fOff ?? _fOff;
    notifyListeners();
  }

  void setCrewAggregation(CrewAggregation aggregation) {
    if (aggregation == _crewAggregation) return;
    _crewAggregation = aggregation;
    notifyListeners();
  }
}
