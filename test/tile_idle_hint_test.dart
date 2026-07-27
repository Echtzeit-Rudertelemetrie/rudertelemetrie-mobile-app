import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/components/dashboard_tiles/bar_tile.dart';
import 'package:rudertelemetrie_mobile_app/components/dashboard_tiles/chart_tile.dart';
import 'package:rudertelemetrie_mobile_app/components/dashboard_tiles/value_tile.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/drive_gated_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/per_stroke_bar_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/time_window_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/stroke_index_combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/time_elapsed_combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/value_vs_value_combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

/// A source that emits only once per stroke, like the stroke engine's.
PushDataSource _strokeSource(String name, Unit unit) => PushDataSource(
  name: name,
  unit: unit,
  group: 'Stroke',
  idleHint: 'No strokes detected yet — one value per stroke.',
);

Visualizer1 _timeWindow() => Visualizer1(
  name: 'Time Window',
  description: 'The last few seconds of a value.',
  shape: VisualizerShape.series,
  combinator: TimeElapsedCombinator(Unit.s),
  buildCollector: (_) => TimeWindowCollector(const Duration(seconds: 20)),
);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 300, height: 300, child: child)),
);

void main() {
  group('a tile says what it is waiting for', () {
    testWidgets('value tile on a per-stroke source', (tester) async {
      final source = _strokeSource('Stroke Rate', Unit.spm);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        _host(ValueTile(visualizer: _timeWindow().bind(source))),
      );
      await tester.pump();

      expect(find.textContaining('No strokes detected yet'), findsOneWidget);
      // The old behaviour: a bold 0.0 that looks like a real reading.
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('value tile switches to the reading on the first stroke', (
      tester,
    ) async {
      final source = _strokeSource('Stroke Rate', Unit.spm);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        _host(ValueTile(visualizer: _timeWindow().bind(source))),
      );
      await tester.pump();

      source.add(Measurement(value: 24, timestamp: DateTime.now()));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('No strokes detected yet'), findsNothing);
      expect(find.text('24.0'), findsOneWidget);
    });

    testWidgets('chart tile on a drive-gated force/angle curve', (
      tester,
    ) async {
      final angle = PushDataSource(name: 'Angle 1', unit: Unit.deg);
      final force = PushDataSource(name: 'Force 1', unit: Unit.N);
      addTearDown(angle.dispose);
      addTearDown(force.dispose);

      final visualizer = Visualizer2(
        name: 'Force vs Angle (Drive)',
        description: 'Force curve over the arc, one drive at a time.',
        shape: VisualizerShape.xy,
        combinator: ValueVsValueCombinator(requireMatchingTimestamps: true),
        buildCollector: (_) => DriveGatedCollector(fOn: 40, fOff: 20),
      );

      await tester.pumpWidget(
        _host(ChartTile(visualizer: visualizer.bind(angle, force))),
      );
      await tester.pump();

      expect(find.textContaining('No drive yet'), findsOneWidget);
      expect(find.textContaining('40 N'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('bar tile on a per-stroke collector', (tester) async {
      final source = _strokeSource('Peak Force / Stroke 1', Unit.N);
      addTearDown(source.dispose);

      final visualizer = Visualizer1(
        name: 'Per-Stroke Bars',
        description: 'One point per completed stroke.',
        shape: VisualizerShape.perStroke,
        combinator: StrokeIndexCombinator(),
        buildCollector: (_) => PerStrokeBarCollector(20),
      );

      await tester.pumpWidget(
        _host(BarTile(visualizer: visualizer.bind(source))),
      );
      await tester.pump();

      expect(find.textContaining('No strokes detected yet'), findsOneWidget);
    });

    testWidgets('an ungated tile still just spins', (tester) async {
      final source = PushDataSource(name: 'Speed', unit: Unit.mps);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        _host(ChartTile(visualizer: _timeWindow().bind(source))),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('resolveIdleHint', () {
    test('prefers the collector over the source', () {
      final source = _strokeSource('Stroke Rate', Unit.spm);
      addTearDown(source.dispose);

      final hint = resolveIdleHint(DriveGatedCollector(fOn: 40, fOff: 20), [
        source,
      ]);

      expect(hint, contains('No drive yet'));
    });

    test('falls back to the first source that declares one', () {
      final plain = PushDataSource(name: 'Speed', unit: Unit.mps);
      final stroke = _strokeSource('Stroke Rate', Unit.spm);
      addTearDown(plain.dispose);
      addTearDown(stroke.dispose);

      final hint = resolveIdleHint(
        TimeWindowCollector(const Duration(seconds: 5)),
        [plain, stroke],
      );

      expect(hint, contains('No strokes detected yet'));
    });

    test('is null when nothing is gated', () {
      final plain = PushDataSource(name: 'Speed', unit: Unit.mps);
      addTearDown(plain.dispose);

      expect(
        resolveIdleHint(TimeWindowCollector(const Duration(seconds: 5)), [
          plain,
        ]),
        isNull,
      );
    });
  });
}
