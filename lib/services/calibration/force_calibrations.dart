import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration_store.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/zero_tracker.dart';

/// Per-oarlock force calibration and live zero tracking, keyed by the stable
/// oarlock key (its source group, e.g. `Oarlock 1 (1A2B)`) so a calibration
/// follows the physical oarlock across reconnects — the same convention
/// `BoatConfig` uses for rig geometry.
///
/// This is the single point where a raw count becomes a physical force. Every
/// consumer downstream sees newtons on the existing `Force N` source and knows
/// nothing about counts, which is why calibration can change without touching
/// the stroke engine, the derived sources, or a saved dashboard.
class ForceCalibrations extends ChangeNotifier {
  /// The offset moves on every sample at 100 Hz, and every listener is UI, so it
  /// is republished at a rate a person can read instead.
  static const _offsetNotifyInterval = Duration(seconds: 1);

  final ForceCalibrationStore? store;

  final Map<String, ForceCalibration> _calibrations = {};
  final Map<String, ZeroTracker> _trackers = {};
  final Map<String, StreamController<int>> _rawTaps = {};

  bool _trackingPaused = false;
  bool _disposed = false;
  DateTime? _lastOffsetNotify;

  ForceCalibrations({this.store});

  ForceCalibration calibrationFor(String oarlockKey) =>
      _calibrations[oarlockKey] ?? ForceCalibration.uncalibrated;

  double offsetFor(String oarlockKey) => _trackers[oarlockKey]?.offset ?? 0;

  bool needsRecalibration(String oarlockKey) =>
      _trackers[oarlockKey]?.needsRecalibration ?? false;

  bool get isTrackingPaused => _trackingPaused;

  /// Every oarlock seen so far, calibrated or not. Uncalibrated ones report the
  /// nominal scale, which is what marks a session's force data provisional.
  Iterable<String> get knownKeys => {..._calibrations.keys, ..._trackers.keys};

  /// What each oarlock is currently reading on, for the session record.
  Map<String, ForceCalibration> snapshot() => {
    for (final key in knownKeys) key: calibrationFor(key),
  };

  /// Raw counts for [oarlockKey], for the calibration flow alone.
  ///
  /// Deliberately not a registered `DataSource`: the calibrated `Force N` is
  /// invertible from its own constants, so a raw series adds nothing a session
  /// needs — and a second `Force` entry per oarlock in the widget picker would
  /// pose a question no rower should have to answer mid-outing.
  Stream<int> rawCounts(String oarlockKey) => _rawTaps
      .putIfAbsent(oarlockKey, () => StreamController<int>.broadcast())
      .stream;

  /// Converts one raw sample to newtons and advances that oarlock's zero
  /// estimate. Called once per sample, per oarlock, at ingest.
  double newtons(String oarlockKey, int raw, DateTime time) {
    _rawTaps[oarlockKey]?.add(raw);
    final force = calibrationFor(oarlockKey).newtons(raw);
    if (_trackingPaused) return force - offsetFor(oarlockKey);

    final offset = _tracker(oarlockKey).update(force, time);
    _notifyOffsetAtHumanRate(time);
    return force - offset;
  }

  Future<void> load() async {
    final stored = await store?.load();
    if (stored == null) return;
    _calibrations
      ..clear()
      ..addAll(stored);
    notifyListeners();
  }

  void setCalibration(String oarlockKey, ForceCalibration calibration) {
    if (_calibrations[oarlockKey] == calibration) return;
    _calibrations[oarlockKey] = calibration;
    _trackers.remove(oarlockKey);
    _persist();
    notifyListeners();
  }

  void removeCalibration(String oarlockKey) {
    if (_calibrations.remove(oarlockKey) == null) return;
    _trackers.remove(oarlockKey);
    _persist();
    notifyListeners();
  }

  /// Hanging a known weight is not drift. Tracking stops for the duration of a
  /// calibration and the poisoned window is dropped on resume.
  void pauseTracking() {
    if (_trackingPaused) return;
    _trackingPaused = true;
    notifyListeners();
  }

  void resumeTracking() {
    if (!_trackingPaused) return;
    _trackingPaused = false;
    _trackers.clear();
    notifyListeners();
  }

  ZeroTracker _tracker(String oarlockKey) =>
      _trackers.putIfAbsent(oarlockKey, ZeroTracker.new);

  void _notifyOffsetAtHumanRate(DateTime time) {
    final last = _lastOffsetNotify;
    if (last != null && time.difference(last) < _offsetNotifyInterval) return;
    _lastOffsetNotify = time;
    if (!_disposed) notifyListeners();
  }

  void _persist() => store?.save(Map.of(_calibrations));

  @override
  void dispose() {
    _disposed = true;
    for (final tap in _rawTaps.values) {
      tap.close();
    }
    _rawTaps.clear();
    super.dispose();
  }
}
