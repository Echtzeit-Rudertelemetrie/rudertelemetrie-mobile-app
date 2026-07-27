import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_aggregate_source.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_event.dart';

const _key = 'Oarlock 1 (T)';

StrokeEvent _evt(StrokeEventType type, int ms) => StrokeEvent(
  type: type,
  oarlockKey: _key,
  time: DateTime.fromMillisecondsSinceEpoch(ms),
);

void main() {
  late PushDataSource base;
  late StreamController<StrokeEvent> events;

  setUp(() {
    base = PushDataSource(name: 'Power 1 (T)', unit: Unit.W, group: 'g');
    events = StreamController<StrokeEvent>.broadcast();
  });

  tearDown(() => events.close());

  StrokeGatedAggregateSource make(StrokeAggregate mode) =>
      StrokeGatedAggregateSource(
        name: 'agg',
        unit: Unit.W,
        base: base,
        events: events.stream,
        oarlockKey: _key,
        mode: mode,
      );

  void addBase(double value, int ms) => base.add(
    Measurement(
      value: value,
      timestamp: DateTime.fromMillisecondsSinceEpoch(ms),
    ),
  );

  test(
    'cycle aggregates: peak, integral, average over previous-finish→finish',
    () async {
      final peak = make(StrokeAggregate.peakOverCycle);
      final integral = make(StrokeAggregate.integralOverCycle);
      final average = make(StrokeAggregate.averageOverCycle);
      addTearDown(() {
        peak.dispose();
        integral.dispose();
        average.dispose();
      });

      final peaks = <double>[];
      final integrals = <double>[];
      final averages = <double>[];
      peak.data.listen((m) => peaks.add(m.value));
      integral.data.listen((m) => integrals.add(m.value));
      average.data.listen((m) => averages.add(m.value));

      events.add(_evt(StrokeEventType.finish, 0)); // seed previous finish
      await pumpEventQueue();

      addBase(100, 0);
      addBase(300, 500); // peak
      addBase(100, 1000);
      await pumpEventQueue();

      events.add(
        _evt(StrokeEventType.finish, 1000),
      ); // close cycle [0, 1000] ms
      await pumpEventQueue();

      expect(peaks.single, 300);
      // trapezoid: 0..0.5s mean 200 ->100 J; 0.5..1s mean 200 ->100 J => 200 J·... (W·s)
      expect(integrals.single, closeTo(200, 1e-6));
      expect(averages.single, closeTo(200, 1e-6)); // 200 J over 1 s
    },
  );

  test('drive aggregates use catch→finish', () async {
    final peakDrive = make(StrokeAggregate.peakOverDrive);
    addTearDown(peakDrive.dispose);
    final peaks = <double>[];
    peakDrive.data.listen((m) => peaks.add(m.value));

    events.add(_evt(StrokeEventType.finish, 0)); // seed
    addBase(50, 100); // before catch (recovery) -> excluded
    events.add(_evt(StrokeEventType.catch_, 200));
    addBase(250, 300); // in drive
    addBase(180, 900);
    events.add(_evt(StrokeEventType.finish, 1000));
    await pumpEventQueue();

    expect(peaks.single, 250); // 50 (pre-catch) excluded
  });

  test('ignores events from other oarlocks', () async {
    final peak = make(StrokeAggregate.peakOverCycle);
    addTearDown(peak.dispose);
    final peaks = <double>[];
    peak.data.listen((m) => peaks.add(m.value));

    events.add(_evt(StrokeEventType.finish, 0));
    addBase(100, 500);
    events.add(
      StrokeEvent(
        type: StrokeEventType.finish,
        oarlockKey: 'Oarlock 2 (T)',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
    );
    await pumpEventQueue();

    expect(peaks, isEmpty);
  });
}
