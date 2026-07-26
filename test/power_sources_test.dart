import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/angular_velocity_source.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/force_sources.dart';

void main() {
  // PO worked example (force-power-model §5): F_D=700, l_in=0.88, L=2.88,
  // ω=2.5 rad/s, v=4.5 m/s, θ=10° ⇒ P_oar≈1070 W, η≈88.6 %, P_prop≈948 W,
  // v_slip≈0.57 m/s.
  test('golden vector: power, propulsion, slip, efficiency', () async {
    final force = PushDataSource(name: 'Force 1 (T)', unit: Unit.N, group: 'Oarlock 1 (T)');
    final angle = PushDataSource(name: 'Angle 1 (T)', unit: Unit.deg, group: 'Oarlock 1 (T)');
    final omega = PushDataSource(name: 'Angular Velocity 1 (T)', unit: Unit.radps, group: 'Oarlock 1 (T)');
    final speed = PushDataSource(name: 'Speed (km/h)', unit: Unit.kmh, group: 'Session');

    final sources = buildPowerSources(
      force: force,
      angle: angle,
      omega: omega,
      speedKmh: speed,
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

    speed.add(Measurement(value: 4.5 * 3.6, timestamp: DateTime.fromMillisecondsSinceEpoch(1))); // loose
    final t = DateTime.fromMillisecondsSinceEpoch(1000);
    force.add(Measurement(value: 700, timestamp: t));
    angle.add(Measurement(value: 10, timestamp: t));
    omega.add(Measurement(value: 2.5, timestamp: t));
    await pumpEventQueue();

    expect(latest['Power 1 (T)'], closeTo(1070, 3));
    expect(latest['Propulsion Power 1 (T)'], closeTo(948, 3));
    expect(latest['Blade Slip 1 (T)'], closeTo(0.57, 0.02));
    expect(latest['Blade Efficiency 1 (T)'], closeTo(88.6, 0.5));
  });

  test('consistency invariant: P_prop ≈ η · P_oar', () async {
    final force = PushDataSource(name: 'Force 1 (T)', unit: Unit.N, group: 'Oarlock 1 (T)');
    final angle = PushDataSource(name: 'Angle 1 (T)', unit: Unit.deg, group: 'Oarlock 1 (T)');
    final omega = PushDataSource(name: 'Angular Velocity 1 (T)', unit: Unit.radps, group: 'Oarlock 1 (T)');
    final speed = PushDataSource(name: 'Speed (km/h)', unit: Unit.kmh, group: 'Session');
    final sources = buildPowerSources(
      force: force,
      angle: angle,
      omega: omega,
      speedKmh: speed,
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

    speed.add(Measurement(value: 4.5 * 3.6, timestamp: DateTime.fromMillisecondsSinceEpoch(1)));
    final t = DateTime.fromMillisecondsSinceEpoch(1000);
    force.add(Measurement(value: 700, timestamp: t));
    angle.add(Measurement(value: 10, timestamp: t));
    omega.add(Measurement(value: 2.5, timestamp: t));
    await pumpEventQueue();

    final pProp = latest['Propulsion Power 1 (T)']!;
    final eta = latest['Blade Efficiency 1 (T)']! / 100;
    final pOar = latest['Power 1 (T)']!;
    expect(pProp, closeTo(eta * pOar, 2));
  });

  test('Power omitted-speed still works; propulsion sources skipped', () async {
    final force = PushDataSource(name: 'Force 1 (T)', unit: Unit.N, group: 'Oarlock 1 (T)');
    final angle = PushDataSource(name: 'Angle 1 (T)', unit: Unit.deg, group: 'Oarlock 1 (T)');
    final omega = PushDataSource(name: 'Angular Velocity 1 (T)', unit: Unit.radps, group: 'Oarlock 1 (T)');
    final sources = buildPowerSources(
      force: force,
      angle: angle,
      omega: omega,
      speedKmh: null,
      rig: const RigConfig(innerLever: 0.88, scullLength: 2.88),
      oarlockKey: 'Oarlock 1 (T)',
    );
    expect(sources.map((s) => s.name), ['Power 1 (T)']);
    for (final s in sources) {
      s.dispose();
    }
  });

  test('AngularVelocitySource converges to a steady angular rate', () async {
    final angle = PushDataSource(name: 'Angle 1 (T)', unit: Unit.deg, group: 'Oarlock 1 (T)');
    final omega = AngularVelocitySource(name: 'ω', angle: angle);
    addTearDown(omega.dispose);

    var last = 0.0;
    omega.data.listen((m) => last = m.value);

    // 1°/10 ms = 100°/s = 1.745 rad/s.
    for (var i = 0; i < 120; i++) {
      angle.add(Measurement(
        value: i.toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(i * 10),
      ));
    }
    await pumpEventQueue();

    expect(last, closeTo(1.745, 0.1));
  });
}
