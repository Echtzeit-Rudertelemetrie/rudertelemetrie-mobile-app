import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_engine.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_settings.dart';

import 'support/stroke_stream.dart';

void main() {
  late DataSourceRegistry registry;
  late StrokeEngine engine;

  setUp(() {
    registry = DataSourceRegistry();
    engine = StrokeEngine(registry: registry, settings: StrokeSettings());
  });

  tearDown(() => engine.dispose());

  PushDataSource register(String name, Unit unit, String group) {
    final source = PushDataSource(name: name, unit: unit, group: group);
    registry.register(source);
    return source;
  }

  Future<void> feed(
    PushDataSource force,
    PushDataSource angle,
    List<StrokeSample> samples,
  ) async {
    for (final s in samples) {
      force.add(Measurement(value: s.force, timestamp: s.time));
      angle.add(Measurement(value: s.angle, timestamp: s.time));
    }
    await pumpEventQueue();
  }

  test('registers the per-stroke sources in the picker', () async {
    await pumpEventQueue();
    final names = registry.all.map((s) => s.name).toSet();
    expect(
      names,
      containsAll(<String>[
        'Stroke Rate',
        'Stroke Count',
        'Drive:Recovery Ratio',
        'Reversal→Catch Time',
        'Distance per Stroke',
        'Catch Angle',
        'Finish Angle',
        'Sweep',
        'Crew Sync (finish)',
      ]),
    );
  });

  test('single oarlock: counts strokes and reports the set rate', () async {
    final force = register('Force 1 (T)', Unit.N, 'Oarlock 1 (T)');
    final angle = register('Angle 1 (T)', Unit.deg, 'Oarlock 1 (T)');
    await pumpEventQueue();

    final counts = <double>[];
    final rates = <double>[];
    registry.get('Stroke Count')!.data.listen((m) => counts.add(m.value));
    registry.get('Stroke Rate')!.data.listen((m) => rates.add(m.value));

    await feed(force, angle, generateStrokeStream(drives: 5));

    expect(counts.last, 4);
    expect(rates.last, closeTo(30, 1.5));
  });

  test('two oarlocks: Crew Sync equals the injected finish offset', () async {
    final force1 = register('Force 1 (T)', Unit.N, 'Oarlock 1 (T)');
    final angle1 = register('Angle 1 (T)', Unit.deg, 'Oarlock 1 (T)');
    final force2 = register('Force 2 (T)', Unit.N, 'Oarlock 2 (T)');
    final angle2 = register('Angle 2 (T)', Unit.deg, 'Oarlock 2 (T)');
    await pumpEventQueue();

    final sync = <double>[];
    registry.get('Crew Sync (finish)')!.data.listen((m) => sync.add(m.value));

    // Both crews row the same cadence; oarlock 2 lags by 100 ms. Feed the two
    // streams interleaved by timestamp, as real sources arrive.
    final s1 = generateStrokeStream(
      drives: 4,
    ).map((s) => (s, force1, angle1)).toList();
    final s2 = generateStrokeStream(
      drives: 4,
      startMs: 100,
    ).map((s) => (s, force2, angle2)).toList();
    final merged = [...s1, ...s2]..sort((a, b) => a.$1.tMs.compareTo(b.$1.tMs));
    for (final (sample, force, angle) in merged) {
      force.add(Measurement(value: sample.force, timestamp: sample.time));
      angle.add(Measurement(value: sample.angle, timestamp: sample.time));
    }
    await pumpEventQueue();

    expect(sync, isNotEmpty);
    expect(sync.last, closeTo(0.1, 0.02));
  });

  group('partial crews', () {
    setUp(() {
      engine.dispose();
      engine = StrokeEngine(
        registry: registry,
        settings: StrokeSettings(),
        quorumWindow: const Duration(milliseconds: 30),
      );
    });

    Future<void> closeQuorum() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await pumpEventQueue();
    }

    test('keeps publishing when one of two oarlocks goes silent', () async {
      final force1 = register('Force 1 (T)', Unit.N, 'Oarlock 1 (T)');
      final angle1 = register('Angle 1 (T)', Unit.deg, 'Oarlock 1 (T)');
      final force2 = register('Force 2 (T)', Unit.N, 'Oarlock 2 (T)');
      final angle2 = register('Angle 2 (T)', Unit.deg, 'Oarlock 2 (T)');
      await pumpEventQueue();

      final rates = <double>[];
      final reporting = <double>[];
      registry.get('Stroke Rate')!.data.listen((m) => rates.add(m.value));
      registry
          .get('Oarlocks Rowing')!
          .data
          .listen((m) => reporting.add(m.value));

      // Oarlock 2 rows one stroke, then stops entirely.
      await feed(force2, angle2, generateStrokeStream(drives: 2));
      await feed(force1, angle1, generateStrokeStream(drives: 5));
      await closeQuorum();

      expect(rates, isNotEmpty);
      expect(reporting.last, 1); // published from the active oarlock alone
    });

    test('reports no crew sync when only one oarlock contributed', () async {
      final force1 = register('Force 1 (T)', Unit.N, 'Oarlock 1 (T)');
      final angle1 = register('Angle 1 (T)', Unit.deg, 'Oarlock 1 (T)');
      register('Force 2 (T)', Unit.N, 'Oarlock 2 (T)');
      register('Angle 2 (T)', Unit.deg, 'Oarlock 2 (T)');
      await pumpEventQueue();

      final sync = <double>[];
      registry.get('Crew Sync (finish)')!.data.listen((m) => sync.add(m.value));

      await feed(force1, angle1, generateStrokeStream(drives: 3));
      await closeQuorum();

      expect(sync, isEmpty);
    });

    test(
      'returns to full-crew aggregation when the silent oarlock resumes',
      () async {
        final force1 = register('Force 1 (T)', Unit.N, 'Oarlock 1 (T)');
        final angle1 = register('Angle 1 (T)', Unit.deg, 'Oarlock 1 (T)');
        final force2 = register('Force 2 (T)', Unit.N, 'Oarlock 2 (T)');
        final angle2 = register('Angle 2 (T)', Unit.deg, 'Oarlock 2 (T)');
        await pumpEventQueue();

        final reporting = <double>[];
        registry
            .get('Oarlocks Rowing')!
            .data
            .listen((m) => reporting.add(m.value));

        await feed(force1, angle1, generateStrokeStream(drives: 3));
        await closeQuorum();
        expect(reporting.last, 1);

        final resumed = generateStrokeStream(drives: 3, startMs: 20000);
        final merged = [
          ...resumed.map((s) => (s, force1, angle1)),
          ...resumed.map((s) => (s, force2, angle2)),
        ]..sort((a, b) => a.$1.tMs.compareTo(b.$1.tMs));
        for (final (sample, force, angle) in merged) {
          force.add(Measurement(value: sample.force, timestamp: sample.time));
          angle.add(Measurement(value: sample.angle, timestamp: sample.time));
        }
        await pumpEventQueue();
        await closeQuorum();

        expect(reporting.last, 2);
      },
    );

    test(
      'an oarlock disconnecting mid-stroke does not stall the crew',
      () async {
        final force1 = register('Force 1 (T)', Unit.N, 'Oarlock 1 (T)');
        final angle1 = register('Angle 1 (T)', Unit.deg, 'Oarlock 1 (T)');
        register('Force 2 (T)', Unit.N, 'Oarlock 2 (T)');
        register('Angle 2 (T)', Unit.deg, 'Oarlock 2 (T)');
        await pumpEventQueue();

        final counts = <double>[];
        registry.get('Stroke Count')!.data.listen((m) => counts.add(m.value));

        await feed(force1, angle1, generateStrokeStream(drives: 3));
        registry.unregister('Force 2 (T)');
        registry.unregister('Angle 2 (T)');
        await pumpEventQueue();

        expect(counts, isNotEmpty);
      },
    );
  });
}
