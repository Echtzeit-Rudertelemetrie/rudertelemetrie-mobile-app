import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';

/// Automatic port/starboard detection from the sign of an oarlock's angular
/// velocity during the drive.
///
/// ## Why not the magnetometer
///
/// The electronics are mounted the *same way round* relative to the hull on
/// both sides, so the magnetometer sees the same field on port and starboard.
/// That was measured on 2026-08-06 and discarded. What does differ is the
/// motion: the two sides swing mirrored, so the angle changes with opposite
/// sign while the rower is pulling.
///
/// ## Sign convention
///
/// The rower sits backwards, so their **left hand side is starboard**. Measured
/// by hand-simulating strokes with real load on the oarlock (2026-08-06):
///
/// | side                       | median dθ/dt in the drive | strokes | range        |
/// |----------------------------|---------------------------|---------|--------------|
/// | starboard (rower's left)   | −30.0 °/s                 | 7       | −55.0 … −3.7 |
/// | port (rower's right)       | +42.3 °/s                 | 14      | +9.4 … +70.1 |
///
/// Every stroke on a side had the same sign and the two distributions did not
/// overlap. So: **negative → starboard, positive → port**.
///
/// Replaying those two captures (`logs/kraft_links.csv`, `logs/kraft_rechts.csv`
/// in the firmware repo) through this detector reproduces them: left settles
/// unanimously on starboard at −24…−39 °/s from the third stroke on, right
/// unanimously on port at +43.2 °/s. It accepts fewer strokes than the manual
/// count — its drive gate is stricter — but never a stroke of the wrong sign.
///
/// ## Limits of the calibration data
///
/// These numbers come from a hand simulation on the bench, *not* from a boat.
/// They were produced by swinging the oarlock by hand while loading the gate,
/// which reproduces the sign but not necessarily the magnitudes a crew
/// generates, and not the boat's own yaw during a stroke. One starboard stroke
/// landed at −3.7 °/s, close enough to zero that a single stroke could plausibly
/// have come out the other way — which is why [minVotes] strokes have to agree
/// before a side is reported, rather than trusting the first one.
class OarSideDetector {
  /// Moving-average length for force and angle, in samples. At the 100 Hz the
  /// sender decimates to, nine samples is 90 ms — short against a drive, long
  /// enough to keep quantisation noise out of the difference quotient.
  static const smoothingWindow = 9;

  /// A run above the force threshold shorter than this is a bump, not a drive.
  static const minDriveDuration = Duration(milliseconds: 250);

  /// How much of the force history the threshold is computed over.
  static const historyWindow = Duration(seconds: 30);

  /// No threshold is published until this much history exists — a threshold
  /// fitted to the first half second is fitted to whatever the gate happened to
  /// be doing then.
  static const warmup = Duration(seconds: 3);

  /// Re-fitting the threshold on every sample would sort the whole history at
  /// 100 Hz for a number that moves over minutes.
  static const thresholdRefresh = Duration(milliseconds: 500);

  /// Where the force threshold sits between the median and the 90th percentile.
  ///
  /// Deliberately *not* derived from the maximum: a single outlier spike (a
  /// knock on the gate, a saturating sample) pushed the threshold above every
  /// real drive and the detection stopped finding strokes at all.
  static const thresholdFraction = 0.5;

  /// Strokes that must agree before a side is reported, and how many recent
  /// strokes are kept to vote with.
  static const minVotes = 3;
  static const voteWindow = 5;

  /// A drive whose median |dθ/dt| is below this is treated as no pull rather
  /// than as a vote. Set below the smallest stroke actually observed (3.7 °/s)
  /// so real strokes still count, while a still oarlock sitting just above a
  /// noise-level threshold contributes nothing.
  static const minVoteRateDegPerSecond = 2.0;

  /// Longer than this without a sample and the stream was interrupted — by a
  /// calibration pause, a dropout, or a reconnect. The angle either side of the
  /// gap is not one continuous motion, so the drive in progress is abandoned.
  static const maxSampleGap = Duration(seconds: 1);

  final _MovingAverage _force = _MovingAverage(smoothingWindow);
  final _MovingAverage _angle = _MovingAverage(smoothingWindow);

  /// Smoothed force, trailing [historyWindow], for the threshold fit.
  final ListQueue<_Timed> _history = ListQueue();

  /// dθ/dt samples inside the drive currently in progress.
  final List<double> _driveRates = [];

  /// One median dθ/dt per completed drive, newest last, at most [voteWindow].
  final ListQueue<double> _votes = ListQueue();

  DateTime? _firstSample;
  DateTime? _lastSample;
  DateTime? _thresholdFittedAt;
  DateTime? _driveStart;
  double? _lastAngle;
  double? _threshold;
  OarSideEstimate? _estimate;

  /// The current reading, or null while fewer than [minVotes] strokes agree.
  OarSideEstimate? get estimate => _estimate;

  /// The force level a drive is counted above, or null during warm-up. Exposed
  /// for the setup UI, which otherwise cannot explain why nothing is detected.
  double? get driveThreshold => _threshold;

  int get completedStrokes => _votes.length;

  /// Feeds one fused `(θ, F)` sample. Returns true when [estimate] changed.
  bool add(double angleDeg, double force, DateTime time) {
    var changed = false;
    if (_isAfterGap(time)) changed = _abandonDrive();

    final previousTime = _lastSample;
    final previousAngle = _lastAngle;
    final smoothedForce = _force.add(force);
    final smoothedAngle = _angle.add(angleDeg);
    _firstSample ??= time;
    _lastSample = time;
    _lastAngle = smoothedAngle;
    _remember(smoothedForce, time);

    final threshold = _refreshThreshold(time);
    if (threshold == null) return changed;

    if (smoothedForce <= threshold) return _closeDrive(time) || changed;

    _driveStart ??= time;
    if (previousTime != null && previousAngle != null) {
      final seconds = time.difference(previousTime).inMicroseconds / 1e6;
      if (seconds > 0) {
        _driveRates.add(_wrapDegrees(smoothedAngle - previousAngle) / seconds);
      }
    }
    return changed;
  }

  bool _isAfterGap(DateTime time) {
    final last = _lastSample;
    return last != null && time.difference(last) > maxSampleGap;
  }

  /// Drops the drive in progress without voting on it. The completed strokes
  /// stay: which side an oarlock is on does not change across a dropout.
  bool _abandonDrive() {
    _driveStart = null;
    _driveRates.clear();
    _lastAngle = null;
    return false;
  }

  void _remember(double force, DateTime time) {
    _history.addLast(_Timed(force, time));
    final cutoff = time.subtract(historyWindow);
    while (_history.isNotEmpty && _history.first.time.isBefore(cutoff)) {
      _history.removeFirst();
    }
  }

  double? _refreshThreshold(DateTime time) {
    final first = _firstSample;
    if (first == null || time.difference(first) < warmup) return null;

    final fitted = _thresholdFittedAt;
    if (fitted != null && time.difference(fitted) < thresholdRefresh) {
      return _threshold;
    }
    _thresholdFittedAt = time;

    final sorted = [for (final entry in _history) entry.value]..sort();
    final median = _medianOfSorted(sorted);
    final p90 = _percentileOfSorted(sorted, 0.9);
    return _threshold = median + thresholdFraction * (p90 - median);
  }

  /// Closes the run above the threshold, if it was long enough to be a drive,
  /// and votes with its median rate. Returns true when [estimate] changed.
  bool _closeDrive(DateTime end) {
    final start = _driveStart;
    final rates = List.of(_driveRates);
    _driveStart = null;
    _driveRates.clear();

    if (start == null || rates.isEmpty) return false;
    if (end.difference(start) < minDriveDuration) return false;

    final median = _median(rates);
    if (median.abs() < minVoteRateDegPerSecond) return false;

    _votes.addLast(median);
    while (_votes.length > voteWindow) {
      _votes.removeFirst();
    }
    return _publish();
  }

  /// Majority vote over the recent strokes. A tie reports nothing rather than
  /// picking one — with a single stroke sitting near zero in the calibration
  /// data, an even split is exactly the case that should not be trusted.
  bool _publish() {
    final previous = _estimate;
    final port = [for (final rate in _votes) if (rate > 0) rate];
    final starboard = [for (final rate in _votes) if (rate < 0) rate];
    final winner = port.length > starboard.length ? port : starboard;

    _estimate = _votes.length >= minVotes && winner.length * 2 > _votes.length
        ? OarSideEstimate(
            side: identical(winner, port) ? OarSide.port : OarSide.starboard,
            agreeingStrokes: winner.length,
            consideredStrokes: _votes.length,
            medianRateDegPerSecond: _median(winner),
          )
        : null;
    return _estimate != previous;
  }

  void reset() {
    _force.reset();
    _angle.reset();
    _history.clear();
    _driveRates.clear();
    _votes.clear();
    _firstSample = null;
    _lastSample = null;
    _thresholdFittedAt = null;
    _driveStart = null;
    _lastAngle = null;
    _threshold = null;
    _estimate = null;
  }
}

/// What the detector currently believes about one oarlock.
@immutable
class OarSideEstimate {
  /// Never [OarSide.both]: the detector reads a swing direction, and a sculler
  /// holding an oar on each side is a crew layout, not a motion.
  final OarSide side;

  /// How many of the [consideredStrokes] recent strokes swung this way.
  final int agreeingStrokes;
  final int consideredStrokes;

  /// Median dθ/dt of the agreeing strokes, signed, for the setup UI to show.
  final double medianRateDegPerSecond;

  const OarSideEstimate({
    required this.side,
    required this.agreeingStrokes,
    required this.consideredStrokes,
    required this.medianRateDegPerSecond,
  });

  bool get isUnanimous => agreeingStrokes == consideredStrokes;

  @override
  bool operator ==(Object other) =>
      other is OarSideEstimate &&
      other.side == side &&
      other.agreeingStrokes == agreeingStrokes &&
      other.consideredStrokes == consideredStrokes &&
      other.medianRateDegPerSecond == medianRateDegPerSecond;

  @override
  int get hashCode => Object.hash(
    side,
    agreeingStrokes,
    consideredStrokes,
    medianRateDegPerSecond,
  );
}

/// Runs one [OarSideDetector] per oarlock and offers the result to
/// [BoatConfig].
///
/// It *offers* rather than applies: [BoatConfig.applyDetectedSide] refuses to
/// touch a side the user set by hand, and the detection never invents a seat,
/// because a swing direction says nothing about where an oarlock sits in the
/// crew. An oarlock the user has not placed at all therefore keeps its estimate
/// here, for the setup screen to show as a suggestion.
class OarSideDetection extends ChangeNotifier {
  final BoatConfig? config;
  final Map<String, OarSideDetector> _detectors = {};

  OarSideDetection({this.config});

  OarSideEstimate? estimateFor(String oarlockKey) =>
      _detectors[oarlockKey]?.estimate;

  int strokesSeenFor(String oarlockKey) =>
      _detectors[oarlockKey]?.completedStrokes ?? 0;

  /// Feeds one fused `(θ, F)` sample for [oarlockKey].
  void add(String oarlockKey, double angleDeg, double force, DateTime time) {
    final detector = _detectors.putIfAbsent(oarlockKey, OarSideDetector.new);
    if (!detector.add(angleDeg, force, time)) return;

    final estimate = detector.estimate;
    if (estimate != null) {
      config?.applyDetectedSide(oarlockKey, estimate.side);
    }
    notifyListeners();
  }

  void forget(String oarlockKey) {
    if (_detectors.remove(oarlockKey) == null) return;
    notifyListeners();
  }
}

/// Fixed-length moving average. Reports the mean of however many samples it has
/// so far, so the very first drive is not skipped waiting for the window to
/// fill.
class _MovingAverage {
  final int length;
  final ListQueue<double> _window = ListQueue();
  double _sum = 0;

  _MovingAverage(this.length);

  double add(double value) {
    _window.addLast(value);
    _sum += value;
    if (_window.length > length) _sum -= _window.removeFirst();
    return _sum / _window.length;
  }

  void reset() {
    _window.clear();
    _sum = 0;
  }
}

class _Timed {
  final double value;
  final DateTime time;
  const _Timed(this.value, this.time);
}

double _median(List<double> values) => _medianOfSorted(List.of(values)..sort());

double _medianOfSorted(List<double> sorted) {
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

double _percentileOfSorted(List<double> sorted, double fraction) =>
    sorted[((sorted.length - 1) * fraction).round()];

/// Shortest signed way round from one angle to the next, so a stroke crossing
/// the ±180° seam does not read as a 360°/sample lurch.
double _wrapDegrees(double delta) {
  while (delta > 180) {
    delta -= 360;
  }
  while (delta <= -180) {
    delta += 360;
  }
  return delta;
}
