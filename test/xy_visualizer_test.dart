import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/smoothed_xy_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/time_window_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/value_vs_value_combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

class _FakeSource extends DataSource {
  @override
  final String name;
  @override
  final Unit unit;
  final Stream<Measurement> _stream;

  _FakeSource(this.name, this.unit, this._stream);

  @override
  DateTime get startTime => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Stream<Measurement> get data => _stream;

  @override
  void dispose() {}
}

Measurement _m(double value, int ms) => Measurement(
  value: value,
  timestamp: DateTime.fromMillisecondsSinceEpoch(ms),
);

XYPoint _p({required double x, required double y, required int ms}) =>
    XYPoint(x: x, y: y, timestamp: DateTime.fromMillisecondsSinceEpoch(ms));

void main() {
  final visualizer = Visualizer2(
    name: 'X vs Y (Window)',
    description: 'Two values plotted against each other.',
    shape: VisualizerShape.xy,
    combinator: ValueVsValueCombinator(),
    buildCollector: (_) => TimeWindowCollector(const Duration(seconds: 10)),
  );

  test(
    'maps source 1 to X, source 2 to Y with combine-latest pairing',
    () async {
      final s1 = _FakeSource(
        'force',
        Unit.N,
        Stream.fromIterable([_m(10, 0), _m(20, 100)]),
      );
      final s2 = _FakeSource(
        'angle',
        Unit.deg,
        Stream.fromIterable([_m(1, 50), _m(2, 150)]),
      );

      final bound = visualizer.bind(s1, s2);

      expect(bound.units.x, Unit.N);
      expect(bound.units.y, Unit.deg);

      final windows = await bound.output.toList();
      final last = windows.last;

      // Latest of each stream once both have fired: (20 N, 2 deg).
      expect(
        last.map((p) => (p.x, p.y)),
        containsAllInOrder(const [(10.0, 1.0), (20.0, 1.0), (20.0, 2.0)]),
      );
    },
  );

  test('drops points older than the collector window', () async {
    final s1 = _FakeSource(
      'force',
      Unit.N,
      Stream.fromIterable([_m(10, 0), _m(20, 20000)]),
    );
    final s2 = _FakeSource(
      'angle',
      Unit.deg,
      Stream.fromIterable([_m(1, 0), _m(2, 20000)]),
    );

    final bound = visualizer.bind(s1, s2);
    final List<XYPoint> last = (await bound.output.toList()).last;

    // Points at t=0 fall outside the 10s window relative to t=20s.
    expect(
      last.every((p) => p.timestamp.millisecondsSinceEpoch >= 20000),
      isTrue,
    );
  });

  group('SmoothedXyCollector', () {
    SmoothedXyCollector build(Duration maxAge) => SmoothedXyCollector(
      TimeWindowCollector(const Duration(seconds: 100)),
      maxAge: maxAge,
    );

    test('keeps the newest point per x, sorted by x', () async {
      final collector = build(const Duration(seconds: 100));
      final out = await Stream.fromIterable([
        _p(x: 2, y: 10, ms: 0),
        _p(x: 1, y: 20, ms: 10),
        _p(x: 2, y: 30, ms: 20), // newer at x=2 → replaces y=10
      ]).transform(collector.collector).toList();

      expect(out.last.map((p) => (p.x, p.y)), const [(1.0, 20.0), (2.0, 30.0)]);
    });

    test('drops points older than maxAge relative to the newest', () async {
      final collector = build(const Duration(seconds: 3));
      final out = await Stream.fromIterable([
        _p(x: 1, y: 5, ms: 0), // stale: 5s older than newest
        _p(x: 2, y: 6, ms: 5000),
      ]).transform(collector.collector).toList();

      expect(out.last.map((p) => p.x), const [2.0]);
    });
  });
}
