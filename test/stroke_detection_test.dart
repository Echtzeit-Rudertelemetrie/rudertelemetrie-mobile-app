import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/oarlock_stroke_detector.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_event.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_settings.dart';

import 'support/stroke_stream.dart';

List<OarlockCycle> runDetector(
  List<StrokeSample> samples, {
  StrokeSettings? settings,
  void Function(StrokeEvent)? onEvent,
}) {
  final cycles = <OarlockCycle>[];
  final detector = OarlockStrokeDetector(
    oarlockKey: 'Oarlock 1 (T)',
    settings: settings ?? StrokeSettings(),
    onEvent: onEvent ?? (_) {},
    onCycle: cycles.add,
  );
  for (final s in samples) {
    detector.add(s.angle, s.force, s.time);
  }
  return cycles;
}

/// A sensor whose zero creeps upward with nobody rowing: force ramps linearly
/// at [newtonsPerSecond] while the angle sits still.
List<StrokeSample> driftRamp({
  double newtonsPerSecond = 5,
  double seconds = 60,
}) {
  const dtMs = 10;
  return [
    for (var i = 0; i < seconds * 1000 / dtMs; i++)
      StrokeSample(i * dtMs, -30, newtonsPerSecond * i * dtMs / 1000),
  ];
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

  group('drift immunity (force-calibration §4.2)', () {
    test('a drift ramp far past F_on produces no stroke at all', () {
      final settings = StrokeSettings();
      // Ends at 300 N — more than seven times F_on — purely from drift.
      final samples = driftRamp(newtonsPerSecond: 5, seconds: 60);
      expect(samples.last.force, greaterThan(settings.fOn * 7));

      final catches = <StrokeEvent>[];
      final cycles = runDetector(
        samples,
        settings: settings,
        onEvent: (e) {
          if (e.type == StrokeEventType.catch_) catches.add(e);
        },
      );

      expect(catches, isEmpty);
      expect(cycles, isEmpty);
    });

    test('a real catch still opens on top of a drifted baseline', () {
      final catches = <StrokeEvent>[];
      runDetector(
        [
          ...driftRamp(newtonsPerSecond: 5, seconds: 30),
          ...generateStrokeStream(
            drives: 5,
            startMs: 30000,
          ).map((s) => StrokeSample(s.tMs, s.angle, s.force + 150)),
        ],
        onEvent: (e) {
          if (e.type == StrokeEventType.catch_) catches.add(e);
        },
      );

      expect(catches, isNotEmpty);
    });

    test('but cycles only close once the offset is removed', () {
      // The rate gate stops drift from opening a false catch; it cannot help a
      // finish, which needs force back under F_off. On a 150 N baseline the
      // recovery never gets there, so no cycle ever closes — that is the half of
      // the problem ZeroTracker exists to solve, and this pins the division of
      // labour between them.
      final rowing = generateStrokeStream(drives: 5, startMs: 30000);
      final onBaseline = rowing
          .map((s) => StrokeSample(s.tMs, s.angle, s.force + 150))
          .toList();

      expect(runDetector(onBaseline), isEmpty);
      expect(runDetector(rowing), isNotEmpty);
    });

    test('a rate gate set above the catch rejects it, so the gate bites', () {
      final settings = StrokeSettings()..setForceRateOn(1e9);

      expect(
        runDetector(generateStrokeStream(drives: 5), settings: settings),
        isEmpty,
      );
    });
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
