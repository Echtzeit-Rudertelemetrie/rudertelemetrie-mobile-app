import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/kinematics/level_reading.dart';

void main() {
  group('LevelReading', () {
    test('flat boat at rest reads level with |g| ≈ 9.81', () {
      final r = LevelReading.fromAccel(0, 0, 9.81);
      expect(r.rollDegrees, closeTo(0, 0.01));
      expect(r.pitchDegrees, closeTo(0, 0.01));
      expect(r.gravity, closeTo(9.81, 0.01));
      expect(r.isGravityReferenced, isTrue);
    });

    test('starboard lean gives positive roll', () {
      final r = LevelReading.fromAccel(0, 9.81 * 0.5, 9.81 * 0.866); // ~30°
      expect(r.rollDegrees, closeTo(30, 0.5));
    });

    test('bow-up trim gives positive pitch (−a_x)', () {
      final r = LevelReading.fromAccel(-9.81 * 0.5, 0, 9.81 * 0.866);
      expect(r.pitchDegrees, closeTo(30, 0.5));
    });

    test('non-gravity acceleration is flagged', () {
      final r = LevelReading.fromAccel(0, 0, 2);
      expect(r.isGravityReferenced, isFalse);
    });
  });

  group('LowPass', () {
    test('converges toward a constant input', () {
      final lp = LowPass(0.5);
      for (var i = 0; i < 200; i++) {
        lp.add(10, 0.01);
      }
      expect(lp.value, closeTo(10, 0.01));
    });

    test('first sample passes through', () {
      final lp = LowPass(0.5);
      expect(lp.add(4.2, 0.01), 4.2);
    });
  });
}
