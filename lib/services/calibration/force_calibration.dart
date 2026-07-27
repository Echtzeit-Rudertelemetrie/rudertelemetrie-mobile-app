/// Standard gravity — turns a calibration mass into the force it applies
/// (force-calibration §2.2). Mass is the input because a user can read `5 kg`
/// off a weight and cannot read `49.03 N` off anything.
const double standardGravity = 9.80665;

/// Full range of the firmware's `uint16` force encoding.
const int rawForceMax = 65535;

/// Smallest distance between the two calibration points that still yields a
/// usable scale, in raw counts (force-calibration §2.3). This is a noise-floor
/// guard, not a target — see [isUnderloadedFor].
const double minSpanCounts = 200;

/// A calibration load below this fraction of the expected peak makes every
/// reading an extrapolation of the span's own error (force-calibration §2.3).
const double minSpanFractionOfPeak = 0.2;

/// Affine raw→newtons mapping for one oarlock's load cell, fitted from two
/// points (force-calibration §2.2).
///
/// A null [calibratedAt] marks the nominal firmware full scale that every
/// oarlock starts on. That scale is a convention rather than a measurement, so
/// its readings are proportional to force and otherwise arbitrary — the UI
/// shows them as provisional, and sessions recorded under one are marked so.
class ForceCalibration {
  /// Averaged unloaded reading, `r₀`.
  final double zeroRaw;

  /// Averaged reading under the calibration load, `r₁`.
  final double spanRaw;

  /// The calibration load itself, `F₁`.
  final double spanNewtons;

  final DateTime? calibratedAt;

  const ForceCalibration({
    required this.zeroRaw,
    required this.spanRaw,
    required this.spanNewtons,
    this.calibratedAt,
  });

  /// The nominal 1000 N full scale the firmware documents, used until an
  /// oarlock has been calibrated for real.
  static const uncalibrated = ForceCalibration(
    zeroRaw: 0,
    spanRaw: 65535,
    spanNewtons: 1000,
  );

  /// Fits a calibration, or returns null when the two points are too close
  /// together to divide by.
  static ForceCalibration? fit({
    required double zeroRaw,
    required double loadedRaw,
    required double massKg,
    required DateTime at,
  }) {
    if (massKg <= 0) return null;
    if (!isUsableSpan(zeroRaw, loadedRaw)) return null;
    return ForceCalibration(
      zeroRaw: zeroRaw,
      spanRaw: loadedRaw,
      spanNewtons: massKg * standardGravity,
      calibratedAt: at,
    );
  }

  /// Magnitude only: a cell wired inverted reads *down* under load and
  /// calibrates just as well, with [scale] carrying the sign.
  static bool isUsableSpan(double zeroRaw, double loadedRaw) =>
      (loadedRaw - zeroRaw).abs() >= minSpanCounts;

  bool get isCalibrated => calibratedAt != null;

  bool get isUsable => isUsableSpan(zeroRaw, spanRaw) && spanNewtons > 0;

  /// Newtons per raw count.
  double get scale => spanNewtons / (spanRaw - zeroRaw);

  double newtons(int raw) => (raw - zeroRaw) * scale;

  /// What the top of the raw range reads as — the sanity figure for the review
  /// step, where a wildly implausible full scale means the weight moved.
  double get fullScaleNewtons => newtons(rawForceMax);

  /// Whether the calibration load was too light to extrapolate from. The
  /// relative error in [scale] multiplies every reading, so calibrating at 50 N
  /// and rowing at 800 N scales the span's error by 16.
  bool isUnderloadedFor(double expectedPeakNewtons) =>
      spanNewtons < minSpanFractionOfPeak * expectedPeakNewtons;

  Map<String, dynamic> toJson() => {
    'zeroRaw': zeroRaw,
    'spanRaw': spanRaw,
    'spanNewtons': spanNewtons,
    'calibratedAt': calibratedAt?.toIso8601String(),
  };

  static ForceCalibration fromJson(Map<String, dynamic> json) {
    final at = json['calibratedAt'];
    return ForceCalibration(
      zeroRaw: (json['zeroRaw'] as num).toDouble(),
      spanRaw: (json['spanRaw'] as num).toDouble(),
      spanNewtons: (json['spanNewtons'] as num).toDouble(),
      calibratedAt: at is String ? DateTime.tryParse(at) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ForceCalibration &&
      other.zeroRaw == zeroRaw &&
      other.spanRaw == spanRaw &&
      other.spanNewtons == spanNewtons &&
      other.calibratedAt == calibratedAt;

  @override
  int get hashCode => Object.hash(zeroRaw, spanRaw, spanNewtons, calibratedAt);
}
