import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibrations.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_engine.dart';

/// Where a calibration has got to (force-calibration §Calibration mode).
enum CalibrationStep {
  idle,
  zeroPrompt,
  capturingZero,
  weightPrompt,
  capturingSpan,
  review,
}

/// Mean and spread of one capture, in raw counts.
class CaptureStatistics {
  final double mean;
  final double standardDeviation;
  final int sampleCount;

  const CaptureStatistics({
    required this.mean,
    required this.standardDeviation,
    required this.sampleCount,
  });

  static CaptureStatistics? of(List<int> samples) {
    if (samples.isEmpty) return null;
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final squaredError = samples
        .map((sample) => math.pow(sample - mean, 2).toDouble())
        .reduce((a, b) => a + b);
    return CaptureStatistics(
      mean: mean,
      standardDeviation: math.sqrt(squaredError / samples.length),
      sampleCount: samples.length,
    );
  }
}

/// Drives the guided two-point calibration of one oarlock
/// (force-calibration §2).
///
/// Owns the side effects that make the procedure safe: stroke segmentation and
/// zero tracking are suspended for its whole duration, because a weight hanging
/// off a load cell is neither a stroke nor drift.
class ForceCalibrationSession extends ChangeNotifier {
  static const captureDuration = Duration(seconds: 2);

  /// Spread above which a capture is refused. In counts, because the zero
  /// capture happens before any scale is known. A starting point — tune against
  /// a real cell.
  static const maxCaptureStdDevCounts = 100.0;

  /// Below this the oarlock is not really streaming.
  static const minCaptureSamples = 20;

  /// Peak gate force assumed when warning that a calibration weight is too light
  /// to extrapolate from. A placeholder until there is field data on what crews
  /// actually pull.
  static const assumedPeakNewtons = 800.0;

  final ForceCalibrations calibrations;
  final StrokeEngine? engine;
  final RecordingSession? recording;

  String? _oarlockKey;
  CalibrationStep _step = CalibrationStep.idle;
  String? _fault;
  CaptureStatistics? _zero;
  CaptureStatistics? _span;
  double? _massKg;
  ForceCalibration? _fitted;

  ForceCalibrationSession({
    required this.calibrations,
    this.engine,
    this.recording,
  });

  String? get oarlockKey => _oarlockKey;
  CalibrationStep get step => _step;
  String? get fault => _fault;
  CaptureStatistics? get zeroCapture => _zero;
  CaptureStatistics? get spanCapture => _span;
  double? get massKg => _massKg;
  ForceCalibration? get fitted => _fitted;

  bool get isActive => _step != CalibrationStep.idle;

  bool get isCapturing =>
      _step == CalibrationStep.capturingZero ||
      _step == CalibrationStep.capturingSpan;

  /// Calibrating mid-recording would silently change the meaning of the data
  /// already in the session.
  bool get isBlockedByRecording => recording?.isRecording ?? false;

  bool get isUnderloaded =>
      _fitted?.isUnderloadedFor(assumedPeakNewtons) ?? false;

  bool begin(String oarlockKey) {
    if (isActive || isBlockedByRecording) return false;
    _oarlockKey = oarlockKey;
    _clearCapture();
    _step = CalibrationStep.zeroPrompt;
    engine?.pause();
    calibrations.pauseTracking();
    notifyListeners();
    return true;
  }

  Future<void> captureZero() async {
    if (_step != CalibrationStep.zeroPrompt) return;
    final stats = await _capture(CalibrationStep.capturingZero);
    if (stats == null) return;
    _zero = stats;
    _enter(CalibrationStep.weightPrompt);
  }

  void setMass(double kg) {
    _massKg = kg;
    notifyListeners();
  }

  Future<void> captureSpan() async {
    if (_step != CalibrationStep.weightPrompt) return;
    final mass = _massKg;
    if (mass == null || mass <= 0) return _fail('Enter the weight first');

    final stats = await _capture(CalibrationStep.capturingSpan);
    if (stats == null) return;
    final fitted = ForceCalibration.fit(
      zeroRaw: _zero!.mean,
      loadedRaw: stats.mean,
      massKg: mass,
      at: DateTime.now(),
    );
    if (fitted == null) {
      return _fail('The reading barely moved — use a heavier weight');
    }
    _span = stats;
    _fitted = fitted;
    _enter(CalibrationStep.review);
  }

  void commit() {
    final key = _oarlockKey;
    final fitted = _fitted;
    if (key == null || fitted == null) return;
    calibrations.setCalibration(key, fitted);
    _finish();
  }

  void cancel() {
    if (!isActive) return;
    _finish();
  }

  Future<CaptureStatistics?> _capture(CalibrationStep during) async {
    final key = _oarlockKey;
    if (key == null) return null;
    _enter(during);

    final samples = <int>[];
    final subscription = calibrations.rawCounts(key).listen(samples.add);
    await Future<void>.delayed(captureDuration);
    // Not awaited: cancelling a broadcast subscription can return a future that
    // never completes, and the capture is already in hand. Awaiting it would
    // strand the step here.
    unawaited(subscription.cancel());

    return _accept(CaptureStatistics.of(samples));
  }

  CaptureStatistics? _accept(CaptureStatistics? stats) {
    if (stats == null || stats.sampleCount < minCaptureSamples) {
      _fail('No data from this oarlock — check that it is still connected');
      return null;
    }
    if (stats.standardDeviation > maxCaptureStdDevCounts) {
      _fail('The reading was unsteady — let it settle and try again');
      return null;
    }
    return stats;
  }

  void _enter(CalibrationStep step) {
    _step = step;
    _fault = null;
    notifyListeners();
  }

  /// Falls back to the prompt for whichever point has not been captured yet, so
  /// a failed capture is retried rather than silently committed.
  void _fail(String message) {
    _fault = message;
    _step = _zero == null
        ? CalibrationStep.zeroPrompt
        : CalibrationStep.weightPrompt;
    notifyListeners();
  }

  void _finish() {
    _step = CalibrationStep.idle;
    _oarlockKey = null;
    _clearCapture();
    calibrations.resumeTracking();
    engine?.resume();
    notifyListeners();
  }

  void _clearCapture() {
    _fault = null;
    _zero = null;
    _span = null;
    _massKg = null;
    _fitted = null;
  }

  /// A capture outlives its screen by up to [captureDuration], so the delayed
  /// continuation can land after disposal. Swallowing the notify there is
  /// cheaper than threading cancellation through every step.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool _disposed = false;
}
