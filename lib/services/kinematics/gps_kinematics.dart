import 'dart:math' as math;

/// A single GPS position fix, already validated by the caller.
class GpsFix {
  final double latitude;
  final double longitude;
  final DateTime time;

  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.time,
  });
}

/// Outcome of feeding one fix into [GpsKinematics].
class GpsStep {
  /// Instantaneous speed over ground (`Δs/Δt`), m/s. Held from the previous
  /// step when the current fix is rejected.
  final double speedMps;

  /// Distance added by this step, m (`0` for the first or a rejected fix).
  final double stepMeters;

  /// Whether the fix passed the plausibility check and was accumulated.
  final bool accepted;

  const GpsStep({
    required this.speedMps,
    required this.stepMeters,
    required this.accepted,
  });
}

/// Great-circle distance between two positions in metres (kinematics §2.2).
double haversineMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371000.0;
  final phi1 = _toRadians(lat1);
  final phi2 = _toRadians(lat2);
  final dPhi = _toRadians(lat2 - lat1);
  final dLambda = _toRadians(lon2 - lon1);

  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
  return 2 * earthRadius * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * math.pi / 180;

/// Derives position-based speed and cumulative distance from a stream of GPS
/// fixes, rejecting glitches (kinematics §1/§2). The firmware speed is
/// integer-truncated, so position is the primary speed/distance source.
class GpsKinematics {
  /// Reject a step whose implied speed exceeds this (a GPS jump), m/s.
  static const double maxPlausibleSpeedMps = 12.0;

  GpsFix? _lastFix;
  double _distanceMeters = 0;
  double _speedMps = 0;

  double get distanceMeters => _distanceMeters;
  double get speedMps => _speedMps;

  GpsStep add(GpsFix fix) {
    final previous = _lastFix;
    if (previous == null) {
      _lastFix = fix;
      return const GpsStep(speedMps: 0, stepMeters: 0, accepted: false);
    }

    final dtSeconds = fix.time.difference(previous.time).inMicroseconds / 1e6;
    if (dtSeconds <= 0) {
      return GpsStep(speedMps: _speedMps, stepMeters: 0, accepted: false);
    }

    final step = haversineMeters(
      previous.latitude,
      previous.longitude,
      fix.latitude,
      fix.longitude,
    );
    final speed = step / dtSeconds;
    if (speed > maxPlausibleSpeedMps) {
      // Glitch: keep the last fix as reference, hold the last speed, no distance.
      return GpsStep(speedMps: _speedMps, stepMeters: 0, accepted: false);
    }

    _lastFix = fix;
    _distanceMeters += step;
    _speedMps = speed;
    return GpsStep(speedMps: speed, stepMeters: step, accepted: true);
  }

  void reset() {
    _lastFix = null;
    _distanceMeters = 0;
    _speedMps = 0;
  }
}
