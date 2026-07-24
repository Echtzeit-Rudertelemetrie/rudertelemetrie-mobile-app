import 'dart:math' as math;

/// Smoothed angular velocity `ω` (rad/s) from a noisy degree-angle stream
/// (stroke-detection §1.2): a 1st-order IIR low-pass followed by a backward
/// difference on the filtered signal. Causal, so it works sample-by-sample on a
/// live stream.
class AngleDifferentiator {
  final double cutoffHz;

  double? _filtered;
  DateTime? _lastTime;
  double _lastOmega = 0;

  AngleDifferentiator(this.cutoffHz);

  double get filteredAngle => _filtered ?? 0;

  double add(double angleDeg, DateTime time) {
    final previousFiltered = _filtered;
    final previousTime = _lastTime;
    if (previousFiltered == null || previousTime == null) {
      _filtered = angleDeg;
      _lastTime = time;
      return 0;
    }

    final dt = time.difference(previousTime).inMicroseconds / 1e6;
    if (dt <= 0) return _lastOmega;

    final rc = 1 / (2 * math.pi * cutoffHz);
    final alpha = dt / (rc + dt);
    final filtered = previousFiltered + alpha * (angleDeg - previousFiltered);

    _filtered = filtered;
    _lastTime = time;
    _lastOmega = (math.pi / 180) * (filtered - previousFiltered) / dt;
    return _lastOmega;
  }

  void reset() {
    _filtered = null;
    _lastTime = null;
    _lastOmega = 0;
  }
}
