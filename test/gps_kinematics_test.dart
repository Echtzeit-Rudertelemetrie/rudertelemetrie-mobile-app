import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/kinematics/gps_kinematics.dart';

/// Degrees of latitude for a north/south displacement of [meters].
double _latDegForMeters(double meters) => meters / 111320.0;

GpsFix _fix(double lat, double lon, int ms) => GpsFix(
  latitude: lat,
  longitude: lon,
  time: DateTime.fromMillisecondsSinceEpoch(ms),
);

void main() {
  group('haversineMeters', () {
    test('is ~zero for identical points', () {
      expect(haversineMeters(47.66, 9.17, 47.66, 9.17), closeTo(0, 1e-6));
    });

    test('matches a known one-degree latitude span (~111 km)', () {
      final d = haversineMeters(0, 0, 1, 0);
      expect(d, closeTo(111195, 50));
    });
  });

  group('GpsKinematics', () {
    test('first fix produces no distance or speed', () {
      final k = GpsKinematics();
      final step = k.add(_fix(0, 0, 0));
      expect(step.accepted, isFalse);
      expect(step.stepMeters, 0);
      expect(k.distanceMeters, 0);
    });

    test('derives ~5 m/s and accumulates distance over fixes', () {
      final k = GpsKinematics();
      k.add(_fix(0, 0, 0));
      final step = k.add(_fix(_latDegForMeters(5), 0, 1000));

      expect(step.accepted, isTrue);
      expect(step.speedMps, closeTo(5, 0.05));
      expect(step.stepMeters, closeTo(5, 0.05));
      expect(k.distanceMeters, closeTo(5, 0.05));
    });

    test('rejects an implausible jump and holds the previous speed', () {
      final k = GpsKinematics();
      k.add(_fix(0, 0, 0));
      k.add(_fix(_latDegForMeters(5), 0, 1000)); // ~5 m/s, accepted

      // 1000 m in 1 s -> 1000 m/s, way over the 12 m/s cap.
      final jump = k.add(_fix(_latDegForMeters(1005), 0, 2000));
      expect(jump.accepted, isFalse);
      expect(jump.stepMeters, 0);
      expect(jump.speedMps, closeTo(5, 0.05));
      expect(k.distanceMeters, closeTo(5, 0.05));
    });

    test('reset clears distance and speed', () {
      final k = GpsKinematics();
      k.add(_fix(0, 0, 0));
      k.add(_fix(_latDegForMeters(5), 0, 1000));
      k.reset();
      expect(k.distanceMeters, 0);
      expect(k.speedMps, 0);
    });
  });
}
