import 'dart:collection';

/// Live zero-offset tracker for one oarlock's force signal
/// (force-calibration §3).
///
/// The load cell's unloaded reading creeps upward over minutes, so a fixed
/// calibration zero goes stale within an outing. The offset is estimated as the
/// minimum force over a trailing window longer than one stroke: the rower
/// applies nothing during recovery, so every such window contains a no-force
/// sample.
///
/// Deliberately independent of stroke detection. A windowed minimum is the same
/// statistic as "the minimum of the previous stroke" to within a stroke of lag,
/// without the `ingest → detector → zero → ingest` feedback loop, and without
/// going blind in exactly the situation where the detector already has.
///
/// Note the estimated zero is *not* the calibration's unloaded zero: in the boat
/// the gate carries the static weight of the oar. Removing that is intended —
/// the quantity of interest is force applied by the rower.
class ZeroTracker {
  /// Must exceed the longest expected stroke period, or a window can miss the
  /// recovery it needs to see.
  static const defaultWindow = Duration(seconds: 5);

  /// Above the physical drift rate, far below any stroke's rate of change.
  static const defaultSlewNewtonsPerSecond = 5.0;

  static const defaultQuietRangeNewtons = 15.0;
  static const defaultForcedSeedDelay = Duration(seconds: 30);
  static const defaultMaxOffsetNewtons = 150.0;

  final Duration window;
  final double slewNewtonsPerSecond;
  final double quietRangeNewtons;
  final Duration forcedSeedDelay;
  final double maxOffsetNewtons;

  final ListQueue<_Extreme> _minima = ListQueue();
  final ListQueue<_Extreme> _maxima = ListQueue();

  DateTime? _firstSample;
  DateTime? _lastSample;
  double _offset = 0;
  bool _seeded = false;

  ZeroTracker({
    this.window = defaultWindow,
    this.slewNewtonsPerSecond = defaultSlewNewtonsPerSecond,
    this.quietRangeNewtons = defaultQuietRangeNewtons,
    this.forcedSeedDelay = defaultForcedSeedDelay,
    this.maxOffsetNewtons = defaultMaxOffsetNewtons,
  });

  double get offset => _offset;

  bool get isSeeded => _seeded;

  /// Past this the sensor has stopped behaving like the thing that was
  /// calibrated. Tracking continues — a stale-but-live zero beats a frozen one —
  /// but silently absorbing this much drift would hide a real fault.
  bool get needsRecalibration => _offset.abs() > maxOffsetNewtons;

  /// Feeds one calibrated sample and returns the offset to subtract from it.
  double update(double newtons, DateTime time) {
    final previous = _lastSample;
    _lastSample = time;
    _record(newtons, time);
    if (!_hasFullWindow(time)) return _offset;

    if (_seeded) {
      _slewToward(_minimum, previous, time);
    } else {
      _trySeed(time);
    }
    return _offset;
  }

  /// Forgets the window and the seed. For a calibration changing underneath, and
  /// for a weight being hung on the sensor — neither of which is drift.
  void reset() {
    _minima.clear();
    _maxima.clear();
    _firstSample = null;
    _lastSample = null;
    _offset = 0;
    _seeded = false;
  }

  void _record(double value, DateTime time) {
    _firstSample ??= time;
    _pushMonotonic(_minima, value, time, descending: false);
    _pushMonotonic(_maxima, value, time, descending: true);
    _evictBefore(time.subtract(window));
  }

  /// Sliding-window extremes in O(1) amortised. At 100 Hz over 5 s a rescan
  /// would burn ~50k comparisons per second per oarlock to recompute a value
  /// that moves at 5 N/s.
  static void _pushMonotonic(
    ListQueue<_Extreme> deque,
    double value,
    DateTime time, {
    required bool descending,
  }) {
    while (deque.isNotEmpty &&
        (descending ? deque.last.value <= value : deque.last.value >= value)) {
      deque.removeLast();
    }
    deque.addLast(_Extreme(value, time));
  }

  void _evictBefore(DateTime cutoff) {
    while (_minima.isNotEmpty && _minima.first.time.isBefore(cutoff)) {
      _minima.removeFirst();
    }
    while (_maxima.isNotEmpty && _maxima.first.time.isBefore(cutoff)) {
      _maxima.removeFirst();
    }
  }

  bool _hasFullWindow(DateTime time) {
    final first = _firstSample;
    return first != null && time.difference(first) >= window;
  }

  double get _minimum => _minima.first.value;

  double get _range => _maxima.first.value - _minima.first.value;

  /// Jumps to the first quiet window rather than ramping from zero at the slew
  /// rate, which would take a minute of rowing to converge. A window that is not
  /// quiet contains a stroke, and seeding to it would bake part of a real pull
  /// into the zero — so a boat that is already moving waits for
  /// [forcedSeedDelay] and then accepts the best estimate available.
  void _trySeed(DateTime time) {
    if (_range >= quietRangeNewtons && !_isSeedOverdue(time)) return;
    _offset = _minimum;
    _seeded = true;
  }

  bool _isSeedOverdue(DateTime time) =>
      time.difference(_firstSample!) >= forcedSeedDelay;

  /// Rate-limited so the offset can follow drift and never a stroke: at 5 N/s an
  /// update landing mid-drive is a ramp invisible under a 700 N pull. This is
  /// what removes the need to synchronise zero updates to stroke boundaries.
  void _slewToward(double target, DateTime? previous, DateTime time) {
    if (previous == null) return;
    final seconds = time.difference(previous).inMicroseconds / 1e6;
    if (seconds <= 0) return;
    final step = slewNewtonsPerSecond * seconds;
    _offset += (target - _offset).clamp(-step, step);
  }
}

class _Extreme {
  final double value;
  final DateTime time;
  const _Extreme(this.value, this.time);
}
