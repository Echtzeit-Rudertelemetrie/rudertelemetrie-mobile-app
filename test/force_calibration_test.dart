import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';

// Inverse of the firmware encoding in rowing_boat SimData::dolle, which the
// nominal (uncalibrated) scale still mirrors.
int _encodeNominal(double newtons) => (newtons / 1000.0 * 65535).round();

ForceCalibration _fitted({
  double zeroRaw = 1000,
  double loadedRaw = 11000,
  double massKg = 20,
}) => ForceCalibration.fit(
  zeroRaw: zeroRaw,
  loadedRaw: loadedRaw,
  massKg: massKg,
  at: DateTime(2026, 7, 27),
)!;

void main() {
  group('nominal scale (uncalibrated)', () {
    const nominal = ForceCalibration.uncalibrated;

    test('reproduces the firmware 0..1000 N mapping exactly', () {
      expect(nominal.newtons(0), closeTo(0, 1e-6));
      expect(nominal.newtons(65535), closeTo(1000, 1e-6));
      expect(nominal.newtons(_encodeNominal(600)), closeTo(600, 0.02));
    });

    test('is flagged as not really calibrated', () {
      expect(nominal.isCalibrated, isFalse);
      expect(nominal.isUsable, isTrue);
    });
  });

  group('two-point fit', () {
    test('maps the calibration load back to its own force', () {
      final calibration = _fitted(massKg: 20);
      final expected = 20 * standardGravity;

      expect(calibration.newtons(11000), closeTo(expected, 1e-9));
      expect(calibration.newtons(1000), closeTo(0, 1e-9));
    });

    test('is linear between and beyond the two points', () {
      final calibration = _fitted(massKg: 20);
      final perCount = 20 * standardGravity / 10000;

      expect(calibration.newtons(6000), closeTo(5000 * perCount, 1e-9));
      expect(calibration.newtons(21000), closeTo(20000 * perCount, 1e-9));
    });

    test('inverts exactly, so a raw series need not be recorded', () {
      final calibration = _fitted();

      for (final raw in [0, 1000, 7531, 40000, rawForceMax]) {
        final recovered =
            calibration.newtons(raw) / calibration.scale + calibration.zeroRaw;
        expect(recovered, closeTo(raw.toDouble(), 1e-6));
      }
    });

    test('records when it was taken', () {
      expect(_fitted().isCalibrated, isTrue);
    });
  });

  group('validity', () {
    test('rejects a span too small to divide by', () {
      expect(
        ForceCalibration.fit(
          zeroRaw: 1000,
          loadedRaw: 1000 + minSpanCounts - 1,
          massKg: 20,
          at: DateTime(2026, 7, 27),
        ),
        isNull,
      );
    });

    test('accepts a span at exactly the minimum', () {
      expect(
        ForceCalibration.fit(
          zeroRaw: 1000,
          loadedRaw: 1000 + minSpanCounts,
          massKg: 20,
          at: DateTime(2026, 7, 27),
        ),
        isNotNull,
      );
    });

    test('rejects a non-positive mass', () {
      expect(
        ForceCalibration.fit(
          zeroRaw: 1000,
          loadedRaw: 11000,
          massKg: 0,
          at: DateTime(2026, 7, 27),
        ),
        isNull,
      );
    });

    test('accepts an inverted cell, carrying the sign in the scale', () {
      final calibration = _fitted(zeroRaw: 11000, loadedRaw: 1000);

      expect(calibration.scale, isNegative);
      expect(calibration.newtons(11000), closeTo(0, 1e-9));
      expect(calibration.newtons(1000), closeTo(20 * standardGravity, 1e-9));
    });
  });

  group('underload warning', () {
    test('flags a weight too light to extrapolate from', () {
      expect(_fitted(massKg: 5).isUnderloadedFor(800), isTrue);
    });

    test('passes a weight at a usable fraction of the peak', () {
      expect(_fitted(massKg: 20).isUnderloadedFor(800), isFalse);
    });
  });

  group('serialisation', () {
    test('round-trips through JSON', () {
      final calibration = _fitted();
      final restored = ForceCalibration.fromJson(calibration.toJson());

      expect(restored, calibration);
      expect(restored.calibratedAt, calibration.calibratedAt);
    });

    test('round-trips the nominal scale as uncalibrated', () {
      final restored = ForceCalibration.fromJson(
        ForceCalibration.uncalibrated.toJson(),
      );

      expect(restored.isCalibrated, isFalse);
      expect(restored, ForceCalibration.uncalibrated);
    });
  });
}
