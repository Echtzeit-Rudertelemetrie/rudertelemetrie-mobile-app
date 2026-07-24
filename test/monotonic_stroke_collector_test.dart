import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/monotonic_stroke_collector.dart';

void main() {
  test('draws each drive left-to-right and ignores angle jitter', () async {
    final start = DateTime(2026);
    XYPoint point(double angle, double force, int index) => XYPoint(
      x: angle,
      y: force,
      timestamp: start.add(Duration(milliseconds: index * 10)),
    );
    final input = Stream.fromIterable([
      point(-65, 0, 0),
      point(-60, 60, 1),
      point(-59, 100, 2),
      point(-59.5, 110, 3), // jitter backwards
      point(-30, 115, 4), // isolated forward spike
      point(-58, 120, 5),
      point(-57, 0, 6), // drive ends
      point(30, 0, 7), // recovery is ignored
      point(-61, 70, 8), // next drive replaces the old curve
      point(-60, 90, 9),
    ]);

    final output = await input
        .transform(MonotonicStrokeCollector(forceThreshold: 50).collector)
        .toList();

    expect(output.map((points) => points.map((point) => point.x).toList()), [
      [-60],
      [-60, -59],
      [-60, -59, -58],
      [-61, -60],
    ]);
  });
}
