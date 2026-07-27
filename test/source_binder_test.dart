import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/source_binder.dart';

void main() {
  late DataSourceRegistry registry;
  late SourceBinder binder;
  late List<double> received;
  late int changes;

  PushDataSource source(String name, {String? group}) =>
      PushDataSource(name: name, unit: Unit.deg, group: group);

  void emit(PushDataSource s, double value) =>
      s.add(Measurement(value: value, timestamp: DateTime.now()));

  setUp(() {
    registry = DataSourceRegistry();
    received = [];
    changes = 0;
    binder = SourceBinder(registry, onChanged: () => changes++);
  });

  tearDown(() => binder.dispose());

  void bindLatitude() => binder.bind(
    'lat',
    matches: byNamePrefix('Latitude'),
    onData: (m) => received.add(m.value),
  );

  test(
    'binds to a source that appears after the binding is declared',
    () async {
      bindLatitude();
      expect(binder.isBound('lat'), isFalse);

      final lat = source('Latitude');
      registry.register(lat);
      expect(binder.isBound('lat'), isTrue);
      expect(changes, 1);

      emit(lat, 47.6);
      await pumpEventQueue();
      expect(received, [47.6]);
    },
  );

  test('rebinds to a replacement instance and drops the old one', () async {
    final first = source('Latitude');
    registry.register(first);
    bindLatitude();

    final second = source('Latitude');
    registry.register(second);

    emit(first, 1);
    emit(second, 2);
    await pumpEventQueue();
    expect(received, [2]);
  });

  test('unbinds when the source disappears', () async {
    final lat = source('Latitude');
    registry.register(lat);
    bindLatitude();

    registry.unregister('Latitude');
    expect(binder.isBound('lat'), isFalse);

    emit(lat, 9);
    await pumpEventQueue();
    expect(received, isEmpty);
  });

  test('matches by group as well as name prefix', () async {
    final angle = source('Angle 1', group: 'Oarlock 1');
    registry.register(source('Angle 2', group: 'Oarlock 2'));
    registry.register(angle);

    binder.bind(
      'o1',
      matches: byGroupAndPrefix('Oarlock 1', 'Angle '),
      onData: (m) => received.add(m.value),
    );

    emit(angle, 30);
    await pumpEventQueue();
    expect(received, [30]);
  });

  test('dispose stops delivery', () async {
    final lat = source('Latitude');
    registry.register(lat);
    bindLatitude();

    binder.dispose();
    emit(lat, 5);
    await pumpEventQueue();
    expect(received, isEmpty);
  });
}
