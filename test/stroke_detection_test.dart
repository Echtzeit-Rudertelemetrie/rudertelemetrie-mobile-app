import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/oarlock_stroke_detector.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_event.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_settings.dart';

import 'support/stroke_stream.dart';

List<OarlockCycle> runDetector(List<StrokeSample> samples) {
  final cycles = <OarlockCycle>[];
  final detector = OarlockStrokeDetector(
    oarlockKey: 'Oarlock 1 (T)',
    settings: StrokeSettings(),
    onEvent: (_) {},
    onCycle: cycles.add,
  );
  for (final s in samples) {
    detector.add(s.angle, s.force, s.time);
  }
  return cycles;
}

void main() {
  test(
    'detects N-1 cycles from N clean drives, with expected SPM and ratio',
    () {
      final cycles = runDetector(generateStrokeStream(drives: 5));

      expect(cycles.length, 4); // 5 finishes seed one, then 4 full cycles
      for (final c in cycles) {
        expect(c.strokesPerMinuteApprox, closeTo(30, 1)); // 2.0 s period
        expect(c.driveRecoveryRatioApprox, closeTo(1.5, 0.1)); // 1.2 / 0.8
        expect(c.sweep, closeTo(60, 2)); // +30 .. -30
      }
    },
  );

  test('rejects a sub-τ_min force blip in the recovery (no extra cycle)', () {
    final baseline = runDetector(generateStrokeStream(drives: 5));
    final withBlip = runDetector(
      generateStrokeStream(drives: 5, blipInRecovery: [2]),
    );

    expect(withBlip.length, baseline.length);
  });

  test('respects a different set rate', () {
    // 1.0 s recovery + 0.5 s drive = 1.5 s period -> 40 SPM, ratio 2.0.
    final cycles = runDetector(
      generateStrokeStream(drives: 4, recoverySeconds: 1.0, driveSeconds: 0.5),
    );
    expect(cycles, isNotEmpty);
    expect(cycles.last.strokesPerMinuteApprox, closeTo(40, 2));
    expect(cycles.last.driveRecoveryRatioApprox, closeTo(2.0, 0.15));
  });
}

extension on OarlockCycle {
  double get strokesPerMinuteApprox {
    final seconds = stroke.inMicroseconds / 1e6;
    return seconds > 0 ? 60 / seconds : 0;
  }

  double get driveRecoveryRatioApprox =>
      recovery.inMicroseconds / drive.inMicroseconds;
}
