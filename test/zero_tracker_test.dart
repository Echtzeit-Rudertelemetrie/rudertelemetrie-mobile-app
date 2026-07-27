import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/zero_tracker.dart';

final _origin = DateTime(2026, 7, 27);

DateTime _at(double seconds) =>
    _origin.add(Duration(microseconds: (seconds * 1e6).round()));

/// Feeds [seconds] of samples at 100 Hz, starting at [from], and returns the
/// time reached.
double _feed(
  ZeroTracker tracker,
  double from,
  double seconds,
  double Function(double t) signal,
) {
  const step = 0.01;
  var t = from;
  final end = from + seconds;
  while (t < end) {
    tracker.update(signal(t), _at(t));
    t += step;
  }
  return t;
}

/// One stroke cycle: a half-sine drive on top of [base], then recovery at
/// [base]. 2 s period ≈ 30 spm.
double Function(double) _strokes({required double base, double peak = 700}) =>
    (t) {
      final phase = t % 2.0;
      if (phase >= 0.8) return base;
      return base + peak * math.sin(math.pi * phase / 0.8);
    };

void main() {
  test('reports no offset until the window has filled', () {
    final tracker = ZeroTracker();

    _feed(tracker, 0, 4.9, (_) => 42);

    expect(tracker.isSeeded, isFalse);
    expect(tracker.offset, 0);
  });

  test('seeds to the resting level on the first quiet window', () {
    final tracker = ZeroTracker();

    _feed(tracker, 0, 6, (_) => 42);

    expect(tracker.isSeeded, isTrue);
    expect(tracker.offset, closeTo(42, 1e-9));
  });

  test('does not seed mid-stroke, so no real pull is baked into the zero', () {
    final tracker = ZeroTracker();

    _feed(tracker, 0, 8, _strokes(base: 30));

    expect(tracker.isSeeded, isFalse);
    expect(tracker.offset, 0);
  });

  test('seeds anyway once overdue, for an app that connected mid-outing', () {
    final tracker = ZeroTracker(forcedSeedDelay: const Duration(seconds: 10));

    _feed(tracker, 0, 12, _strokes(base: 30));

    expect(tracker.isSeeded, isTrue);
    expect(tracker.offset, closeTo(30, 1.0));
  });

  test('follows slow drift, trailing it by one window', () {
    final tracker = ZeroTracker(window: const Duration(seconds: 5));

    var t = _feed(tracker, 0, 6, (_) => 0);
    expect(tracker.offset, closeTo(0, 1e-9));

    // 1 N/s for 30 s, comfortably inside the 5 N/s slew limit.
    _feed(tracker, t, 30, (s) => s - 6);

    // A trailing minimum of a ramp is the value one window ago, so a sustained
    // drift leaves a residual of window × rate — here 5 s × 1 N/s.
    expect(tracker.offset, closeTo(25, 0.5));
  });

  test('leaves a residual proportional to the window under steady drift', () {
    final slow = ZeroTracker(window: const Duration(seconds: 2));

    var t = _feed(slow, 0, 3, (_) => 0);
    _feed(slow, t, 30, (s) => s - 3);

    expect(slow.offset, closeTo(28, 0.5));
  });

  test('cannot chase a stroke: a step is followed at the slew rate', () {
    final tracker = ZeroTracker(slewNewtonsPerSecond: 5);

    var t = _feed(tracker, 0, 6, (_) => 0);
    t = _feed(tracker, t, 1, (_) => 700);

    // One second of a 700 N pull may move the zero by at most 5 N.
    expect(tracker.offset, lessThanOrEqualTo(5.01));
  });

  test('tracks the recovery level under a stroke train, not the peaks', () {
    final tracker = ZeroTracker();

    var t = _feed(tracker, 0, 6, (_) => 20);
    expect(tracker.offset, closeTo(20, 1e-9));

    _feed(tracker, t, 20, _strokes(base: 20));

    expect(tracker.offset, closeTo(20, 1.0));
  });

  test('flags a runaway offset for recalibration but keeps tracking', () {
    final tracker = ZeroTracker(maxOffsetNewtons: 20);

    var t = _feed(tracker, 0, 6, (_) => 0);
    _feed(tracker, t, 30, (_) => 100);

    expect(tracker.needsRecalibration, isTrue);
    expect(tracker.offset, greaterThan(20));
  });

  test('forgets the window and the seed on reset', () {
    final tracker = ZeroTracker();

    _feed(tracker, 0, 6, (_) => 42);
    expect(tracker.isSeeded, isTrue);

    tracker.reset();

    expect(tracker.isSeeded, isFalse);
    expect(tracker.offset, 0);
  });

  test('re-seeds from scratch after a reset', () {
    final tracker = ZeroTracker();

    var t = _feed(tracker, 0, 6, (_) => 42);
    tracker.reset();
    _feed(tracker, t, 6, (_) => 90);

    expect(tracker.offset, closeTo(90, 1e-9));
  });
}
