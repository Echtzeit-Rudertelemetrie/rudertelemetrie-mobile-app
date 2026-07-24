import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/drive_gated_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/per_stroke_bar_collector.dart';

XYPoint _p(double x, double y) =>
    XYPoint(x: x, y: y, timestamp: DateTime.fromMillisecondsSinceEpoch(x.toInt()));

void main() {
  group('PerStrokeBarCollector', () {
    test('keeps a rolling window of the last K points', () async {
      final collector = PerStrokeBarCollector(3);
      final out = await Stream.fromIterable([
        _p(0, 10),
        _p(1, 11),
        _p(2, 12),
        _p(3, 13),
        _p(4, 14),
      ]).transform(collector.collector).toList();

      expect(out.last.map((p) => p.y), [12, 13, 14]);
      expect(out.last.length, 3);
    });

    test('emits growing windows until K is reached', () async {
      final collector = PerStrokeBarCollector(5);
      final out = await Stream.fromIterable([_p(0, 1), _p(1, 2)])
          .transform(collector.collector)
          .toList();

      expect(out.map((w) => w.length), [1, 2]);
    });
  });

  group('DriveGatedCollector', () {
    test('collects one drive from catch (F_on) to finish (F_off)', () async {
      final collector = DriveGatedCollector(fOn: 40, fOff: 20);
      // angle sweeps as force rises above 40 then falls below 20.
      final out = await Stream.fromIterable([
        _p(30, 10), // recovery, ignored
        _p(28, 45), // catch
        _p(10, 200),
        _p(-10, 120),
        _p(-25, 15), // finish (<20)
        _p(-30, 5), // recovery again, ignored
      ]).transform(collector.collector).toList();

      final drive = out.last;
      expect(drive.map((p) => p.y), [45, 200, 120, 15]);
    });

    test('a new catch clears the previous drive buffer', () async {
      final collector = DriveGatedCollector(fOn: 40, fOff: 20);
      final out = await Stream.fromIterable([
        _p(28, 45), // catch 1
        _p(-25, 10), // finish 1
        _p(27, 60), // catch 2 -> buffer cleared
        _p(-20, 90),
      ]).transform(collector.collector).toList();

      expect(out.last.map((p) => p.y), [60, 90]);
    });
  });
}
