/// One synthetic fused sample.
class StrokeSample {
  final int tMs;
  final double angle;
  final double force;
  const StrokeSample(this.tMs, this.angle, this.force);

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(tMs);
}

/// Generates `drives` clean stroke phases (recovery then drive) at 100 Hz. The
/// first sample of each recovery closes the preceding drive (force → 0), and a
/// trailing recovery sample closes the last drive, so `drives` finishes are
/// produced ⇒ `drives − 1` full cycles. Angle sweeps −30°↔+30°, drive force is a
/// flat 200 N. Optionally injects a short sub-`τ_min` force blip into the
/// recovery phases listed in [blipInRecovery].
List<StrokeSample> generateStrokeStream({
  int drives = 4,
  double recoverySeconds = 1.2,
  double driveSeconds = 0.8,
  int startMs = 0,
  List<int> blipInRecovery = const [],
}) {
  const dtMs = 10;
  final out = <StrokeSample>[];
  var tMs = startMs;

  void recovery(bool blip) {
    final steps = (recoverySeconds * 1000 / dtMs).round();
    for (var i = 0; i < steps; i++) {
      final frac = i / steps;
      final blipHere = blip && i >= steps ~/ 2 && i < steps ~/ 2 + 5;
      out.add(StrokeSample(tMs, -30 + 60 * frac, blipHere ? 100 : 0));
      tMs += dtMs;
    }
  }

  void drive() {
    final steps = (driveSeconds * 1000 / dtMs).round();
    for (var i = 0; i < steps; i++) {
      final frac = i / steps;
      out.add(StrokeSample(tMs, 30 - 60 * frac, 200));
      tMs += dtMs;
    }
  }

  for (var d = 0; d < drives; d++) {
    recovery(blipInRecovery.contains(d));
    drive();
  }
  out.add(StrokeSample(tMs, -30, 0)); // close the final drive
  return out;
}
