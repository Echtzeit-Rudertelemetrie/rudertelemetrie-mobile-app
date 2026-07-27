import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/components/dashboard_tiles/chart_tile.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/drive_gated_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/collectors/time_window_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/time_elapsed_combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinators/value_vs_value_combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

/// Force vs Angle: a `Stream.multi` combinator into an `async*` collector, the
/// combination that yields a strictly single-subscription pipeline.
BoundVisualizer _driveGated(PushDataSource angle, PushDataSource force) =>
    Visualizer2(
      name: 'Force vs Angle (Drive)',
      combinator: ValueVsValueCombinator(requireMatchingTimestamps: true),
      buildCollector: (_) => DriveGatedCollector(fOn: 40, fOff: 20),
    ).bind(angle, force);

BoundVisualizer _timeWindow(PushDataSource source) => Visualizer1(
  name: 'Time Window',
  combinator: TimeElapsedCombinator(Unit.s),
  buildCollector: (_) => TimeWindowCollector(const Duration(seconds: 20)),
).bind(source);

void main() {
  test('a single-subscription pipeline takes more than one listener', () async {
    final source = PushDataSource(name: 'Speed', unit: Unit.mps);
    addTearDown(source.dispose);
    final bound = _timeWindow(source);
    addTearDown(bound.dispose);

    final first = <List<XYPoint>>[];
    final second = <List<XYPoint>>[];
    bound.output.listen(first.add);
    bound.output.listen(second.add);

    source.add(Measurement(value: 3, timestamp: DateTime(2026)));
    await Future<void>.delayed(Duration.zero);

    expect(first.single.single.y, 3);
    expect(second.single.single.y, 3);
  });

  test('a late listener is given the most recent points immediately', () async {
    final source = PushDataSource(name: 'Speed', unit: Unit.mps);
    addTearDown(source.dispose);
    final bound = _timeWindow(source);
    addTearDown(bound.dispose);

    bound.output.listen((_) {});
    source.add(Measurement(value: 7, timestamp: DateTime(2026)));
    await Future<void>.delayed(Duration.zero);

    final late = <List<XYPoint>>[];
    bound.output.listen(late.add);
    await Future<void>.delayed(Duration.zero);

    expect(late.single.single.y, 7);
  });

  test('the pipeline is not subscribed until something listens', () async {
    final source = PushDataSource(name: 'Speed', unit: Unit.mps);
    addTearDown(source.dispose);
    final bound = _timeWindow(source);
    addTearDown(bound.dispose);

    source.add(Measurement(value: 1, timestamp: DateTime(2026)));
    await Future<void>.delayed(Duration.zero);

    final points = <List<XYPoint>>[];
    bound.output.listen(points.add);
    await Future<void>.delayed(Duration.zero);

    expect(points, isEmpty); // nothing replayed from before the first listener
  });

  test('dispose ends every listener', () async {
    final source = PushDataSource(name: 'Speed', unit: Unit.mps);
    addTearDown(source.dispose);
    final bound = _timeWindow(source);

    var done = false;
    bound.output.listen((_) {}, onDone: () => done = true);
    await Future<void>.delayed(Duration.zero);

    bound.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(done, isTrue);
  });

  // Regression: entering edit mode wraps every tile in a GestureDetector, which
  // remounts the tile's State against the binding the cache deliberately kept.
  // The gated pipelines threw "Stream has already been listened to".
  testWidgets('a tile remounted on the same binding does not throw', (
    tester,
  ) async {
    final angle = PushDataSource(name: 'Angle 1', unit: Unit.deg);
    final force = PushDataSource(name: 'Force 1', unit: Unit.N);
    addTearDown(angle.dispose);
    addTearDown(force.dispose);

    final bound = _driveGated(angle, force);
    addTearDown(bound.dispose);

    Widget host({required bool editMode}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 300,
          child: editMode
              ? GestureDetector(
                  onTap: () {},
                  child: ChartTile(visualizer: bound),
                )
              : ChartTile(visualizer: bound),
        ),
      ),
    );

    await tester.pumpWidget(host(editMode: false));
    await tester.pump();

    await tester.pumpWidget(host(editMode: true));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(host(editMode: false));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a remounted chart keeps its curve instead of going blank', (
    tester,
  ) async {
    final source = PushDataSource(name: 'Speed', unit: Unit.mps);
    addTearDown(source.dispose);
    final bound = _timeWindow(source);
    addTearDown(bound.dispose);

    Widget host({required bool editMode}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 300,
          child: editMode
              ? GestureDetector(
                  onTap: () {},
                  child: ChartTile(visualizer: bound),
                )
              : ChartTile(visualizer: bound),
        ),
      ),
    );

    await tester.pumpWidget(host(editMode: false));
    source.add(Measurement(value: 5, timestamp: DateTime(2026)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(host(editMode: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    expect(tester.takeException(), isNull);
    // Replayed, so the chart draws rather than falling back to the spinner.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
