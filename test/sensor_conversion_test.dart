import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/utils/sensor_data/angle_conversion_util.dart';

// Inverse of the firmware encoding in rowing_boat SimData::dolle.
int _encodeAngle(double degrees) => ((degrees + 180.0) / 360.0 * 65535).round();

// Force scaling moved to force_calibration_test.dart: the raw force count has no
// fixed physical meaning any more, only a per-oarlock calibrated one.

void main() {
  group('angle scaling (-180..+180 degrees full scale)', () {
    test('zero maps to -180 degrees', () {
      expect(convertAngleSensorData(0), closeTo(-180, 1e-6));
    });

    test('full scale maps to +180 degrees', () {
      expect(convertAngleSensorData(65535), closeTo(180, 1e-6));
    });

    test('midpoint maps to 0 degrees', () {
      expect(convertAngleSensorData(32768), closeTo(0, 0.01));
    });

    test('round-trips a firmware-encoded angle value', () {
      expect(convertAngleSensorData(_encodeAngle(-60)), closeTo(-60, 0.01));
      expect(convertAngleSensorData(_encodeAngle(30)), closeTo(30, 0.01));
    });
  });
}
