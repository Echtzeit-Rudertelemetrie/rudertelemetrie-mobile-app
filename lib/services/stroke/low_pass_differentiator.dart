import 'dart:math' as math;

/// A 1st-order IIR low-pass followed by a backward difference on the filtered
/// signal (stroke-detection §1.2). Causal, so it works sample-by-sample on a
/// live stream; the filter is what keeps the derivative from being dominated by
/// sample noise.
///
/// Shared by the angle (for `ω`) and the force (for the catch's rate gate),
/// which differ only in cutoff and in the units they report.
class LowPassDifferentiator {
  final double cutoffHz;

  double? _filtered;
  DateTime? _lastTime;
  double _rate = 0;

  LowPassDifferentiator(this.cutoffHz);

  double get filtered => _filtered ?? 0;

  double get rate => _rate;

  /// Feeds one sample and returns the filtered signal's rate of change, in the
  /// input's units per second.
  double add(double value, DateTime time) {
    final previousValue = _filtered;
    final previousTime = _lastTime;
    if (previousValue == null || previousTime == null) {
      _filtered = value;
      _lastTime = time;
      return 0;
    }

    final seconds = time.difference(previousTime).inMicroseconds / 1e6;
    if (seconds <= 0) return _rate;

    final rc = 1 / (2 * math.pi * cutoffHz);
    final alpha = seconds / (rc + seconds);
    final filtered = previousValue + alpha * (value - previousValue);

    _filtered = filtered;
    _lastTime = time;
    _rate = (filtered - previousValue) / seconds;
    return _rate;
  }

  void reset() {
    _filtered = null;
    _lastTime = null;
    _rate = 0;
  }
}
