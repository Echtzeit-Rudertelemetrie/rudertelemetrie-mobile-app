import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/utils/sensor_data/angle_conversion_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/sensor_data/force_conversion_util.dart';

// Inverse of the firmware encoding in rowing_boat SimData::dolle.
int _encodeForce(double newtons) => (newtons / 1000.0 * 65535).round();
int _encodeAngle(double degrees) => ((degrees + 90.0) / 180.0 * 65535).round();

void main() {
  group('force scaling (0..1000 N full scale)', () {
    test('zero maps to 0 N', () {
      expect(convertForceSensorData(0), closeTo(0, 1e-6));
    });

    test('full scale maps to 1000 N', () {
      expect(convertForceSensorData(65535), closeTo(1000, 1e-6));
    });

    test('round-trips a firmware-encoded force value', () {
      expect(convertForceSensorData(_encodeForce(600)), closeTo(600, 0.02));
    });
  });

  group('angle scaling (-90..+90 degrees full scale)', () {
    test('zero maps to -90 degrees', () {
      expect(convertAngleSensorData(0), closeTo(-90, 1e-6));
    });

    test('full scale maps to +90 degrees', () {
      expect(convertAngleSensorData(65535), closeTo(90, 1e-6));
    });

    test('round-trips a firmware-encoded angle value', () {
      expect(convertAngleSensorData(_encodeAngle(-60)), closeTo(-60, 0.01));
      expect(convertAngleSensorData(_encodeAngle(30)), closeTo(30, 0.01));
    });
  });
}
