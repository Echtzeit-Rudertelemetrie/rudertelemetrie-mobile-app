import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/force_source_registrar.dart';

const _key = 'Oarlock 1 (T)';
const _derived = [
  'Handle Force 1 (T)',
  'Blade Force 1 (T)',
  'Effective Force 1 (T)',
  'Lateral Force 1 (T)',
];

void main() {
  late DataSourceRegistry registry;
  late BoatConfig config;
  late ForceSourceRegistrar registrar;

  setUp(() {
    registry = DataSourceRegistry();
    config = BoatConfig();
    registrar = ForceSourceRegistrar(registry: registry, config: config);
    registry.register(
      PushDataSource(name: 'Force 1 (T)', unit: Unit.N, group: _key),
    );
    registry.register(
      PushDataSource(name: 'Angle 1 (T)', unit: Unit.deg, group: _key),
    );
  });

  tearDown(() => registrar.dispose());

  bool derivedPresent() => _derived.every((name) => registry.get(name) != null);
  bool anyDerived() => _derived.any((name) => registry.get(name) != null);

  test('gate: no derived force sources until a rig is configured', () async {
    await pumpEventQueue();
    expect(derivedPresent(), isFalse);

    config.setRig(_key, const RigConfig(innerLever: 0.88, scullLength: 2.88));
    await pumpEventQueue();
    expect(derivedPresent(), isTrue);
  });

  test('invalid rig (l_out <= 0) does not register sources', () async {
    config.setRig(_key, const RigConfig(innerLever: 3.0, scullLength: 2.88));
    await pumpEventQueue();
    expect(derivedPresent(), isFalse);
  });

  test('removing the rig unregisters the derived sources', () async {
    config.setRig(_key, const RigConfig(innerLever: 0.88, scullLength: 2.88));
    await pumpEventQueue();
    expect(derivedPresent(), isTrue);

    config.removeRig(_key);
    await pumpEventQueue();
    expect(anyDerived(), isFalse);
  });

  test('disconnecting the oarlock unregisters the derived sources', () async {
    config.setRig(_key, const RigConfig(innerLever: 0.88, scullLength: 2.88));
    await pumpEventQueue();
    expect(derivedPresent(), isTrue);

    registry.unregister('Force 1 (T)');
    registry.unregister('Angle 1 (T)');
    await pumpEventQueue();
    expect(anyDerived(), isFalse);
  });
}
