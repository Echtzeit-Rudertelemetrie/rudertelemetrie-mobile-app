import 'dart:math' as math;

/// Boat attitude from the gravity vector in the boat frame (kinematics §6).
/// Axes (m/s²): `acc_z` up, `acc_x` longitudinal (surge), `acc_y` lateral.
class LevelReading {
  /// Port/starboard lean (rad): `atan2(a_y, a_z)`.
  final double roll;

  /// Bow/stern trim (rad): `atan2(−a_x, √(a_y²+a_z²))`.
  final double pitch;

  /// Gravity magnitude (m/s²); ≈ 9.81 when the reading is gravity-referenced.
  final double gravity;

  const LevelReading({
    required this.roll,
    required this.pitch,
    required this.gravity,
  });

  double get rollDegrees => roll * 180 / math.pi;
  double get pitchDegrees => pitch * 180 / math.pi;

  /// Whether |g| is close enough to 9.81 to trust the level (else the accel
  /// isn't gravity-dominated — show a warning instead).
  bool get isGravityReferenced => (gravity - 9.81).abs() < 2.5;

  static LevelReading fromAccel(double ax, double ay, double az) => LevelReading(
        roll: math.atan2(ay, az),
        pitch: math.atan2(-ax, math.sqrt(ay * ay + az * az)),
        gravity: math.sqrt(ax * ax + ay * ay + az * az),
      );
}

/// First-order IIR low-pass with a fixed time constant, for damping rowing
/// acceleration out of the level reading (cutoff < 0.5 Hz, math §6).
class LowPass {
  final double cutoffHz;
  double? _value;

  LowPass(this.cutoffHz);

  double get value => _value ?? 0;

  double add(double sample, double dtSeconds) {
    final previous = _value;
    if (previous == null || dtSeconds <= 0) {
      _value = sample;
      return _value!;
    }
    final rc = 1 / (2 * math.pi * cutoffHz);
    final alpha = dtSeconds / (rc + dtSeconds);
    _value = previous + alpha * (sample - previous);
    return _value!;
  }
}
