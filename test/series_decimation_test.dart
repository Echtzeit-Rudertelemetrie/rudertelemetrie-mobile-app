import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/series_decimation.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

List<SessionSample> _ramp(int count) => [
  for (var i = 0; i < count; i++) SessionSample(i * 5, i.toDouble()),
];

void main() {
  test('leaves a series that already fits alone', () {
    final samples = _ramp(100);
    expect(
      identical(decimateSeries(samples, maxPoints: 1500), samples),
      isTrue,
    );
  });

  test('bounds the output length', () {
    for (final count in [2000, 50000, 120000]) {
      expect(
        decimateSeries(_ramp(count), maxPoints: 1500).length,
        lessThanOrEqualTo(1500),
      );
    }
  });

  test('keeps peaks that stride sampling would drop', () {
    final samples = [
      for (var i = 0; i < 10000; i++)
        SessionSample(i * 5, math.sin(i / 50) * 100),
    ];
    // A single spike between two sampling strides.
    samples[4321] = const SessionSample(4321 * 5, 999);

    final decimated = decimateSeries(samples, maxPoints: 500);
    expect(decimated.map((s) => s.value), contains(999));
  });

  test('preserves the true minimum and maximum', () {
    final samples = _ramp(20000);
    final decimated = decimateSeries(samples, maxPoints: 400);

    expect(decimated.first.value, 0);
    expect(decimated.last.value, 19999);
  });

  test('stays ordered in time', () {
    final decimated = decimateSeries([
      for (var i = 0; i < 5000; i++) SessionSample(i * 5, math.cos(i / 7) * 50),
    ], maxPoints: 300);

    for (var i = 1; i < decimated.length; i++) {
      expect(
        decimated[i].elapsedMs,
        greaterThanOrEqualTo(decimated[i - 1].elapsedMs),
      );
    }
  });
}
