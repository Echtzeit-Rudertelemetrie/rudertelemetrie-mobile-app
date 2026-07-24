import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/value_vs_value_combinator.dart';

void main() {
  test('pairs angle and force only when their timestamps match', () async {
    final angles = StreamController<Measurement>.broadcast();
    final forces = StreamController<Measurement>.broadcast();
    final points = <({double x, double y})>[];
    final subscription = ValueVsValueCombinator()
        .call(angles.stream, forces.stream)
        .listen((point) => points.add((x: point.x, y: point.y)));
    final first = DateTime(2026);
    final second = first.add(const Duration(milliseconds: 5));

    angles.add(Measurement(value: -60, timestamp: first));
    forces.add(Measurement(value: 100, timestamp: first));
    forces.add(Measurement(value: 110, timestamp: second));
    angles.add(Measurement(value: -59, timestamp: second));
    await Future<void>.delayed(Duration.zero);

    expect(points, [(x: -60, y: 100), (x: -59, y: 110)]);

    await subscription.cancel();
    await angles.close();
    await forces.close();
  });
}
