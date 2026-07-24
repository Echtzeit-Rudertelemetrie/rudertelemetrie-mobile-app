import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/force_sources.dart';

void main() {
  // PO worked example (force-power-model §5): F_D=700, l_in=0.88, L=2.88, θ=10°.
  test('golden vector: handle/blade/effective/lateral force', () async {
    final force = PushDataSource(name: 'Force 1 (T)', unit: Unit.N, group: 'Oarlock 1 (T)');
    final angle = PushDataSource(name: 'Angle 1 (T)', unit: Unit.deg, group: 'Oarlock 1 (T)');
    final sources = buildForceSources(
      force: force,
      angle: angle,
      rig: const RigConfig(innerLever: 0.88, scullLength: 2.88),
      oarlockKey: 'Oarlock 1 (T)',
    );
    addTearDown(() {
      for (final s in sources) {
        s.dispose();
      }
    });

    final latest = <String, double>{};
    for (final s in sources) {
      s.data.listen((m) => latest[s.name] = m.value);
    }

    final t = DateTime.fromMillisecondsSinceEpoch(1000);
    force.add(Measurement(value: 700, timestamp: t));
    angle.add(Measurement(value: 10, timestamp: t));
    await pumpEventQueue();

    expect(latest['Handle Force 1 (T)'], closeTo(486.1, 0.5));
    expect(latest['Blade Force 1 (T)'], closeTo(213.9, 0.5));
    expect(latest['Effective Force 1 (T)'], closeTo(210.6, 0.5));
    expect(latest['Lateral Force 1 (T)'], closeTo(37.1, 0.5));
  });

  test('sources appear in the "Force & Power" group', () {
    final force = PushDataSource(name: 'Force 1 (T)', unit: Unit.N, group: 'Oarlock 1 (T)');
    final angle = PushDataSource(name: 'Angle 1 (T)', unit: Unit.deg, group: 'Oarlock 1 (T)');
    final sources = buildForceSources(
      force: force,
      angle: angle,
      rig: const RigConfig(innerLever: 0.88, scullLength: 2.88),
      oarlockKey: 'Oarlock 1 (T)',
    );
    addTearDown(() {
      for (final s in sources) {
        s.dispose();
      }
    });

    expect(
      sources.map((DataSource s) => s.group).toSet(),
      {'Force & Power (Oarlock 1 (T))'},
    );
    expect(
      sources.map((s) => s.name),
      containsAll(<String>[
        'Handle Force 1 (T)',
        'Blade Force 1 (T)',
        'Effective Force 1 (T)',
        'Lateral Force 1 (T)',
      ]),
    );
  });
}
