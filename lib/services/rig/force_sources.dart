import 'dart:math' as math;

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/derived/combine_latest_source.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';

double _radians(double degrees) => degrees * math.pi / 180;

/// Builds the per-sample force sources for one oarlock from its measured
/// `Force`/`Angle` sources and rig geometry (force-power-model §1, §3). Power,
/// slip and efficiency need `ω` and arrive in a later phase.
List<DataSource> buildForceSources({
  required DataSource force,
  required DataSource angle,
  required RigConfig rig,
  required String oarlockKey,
}) {
  final suffix = force.name.replaceFirst('Force ', '');
  final group = 'Force & Power ($oarlockKey)';
  final lIn = rig.innerLever;
  final l = rig.scullLength;
  final lOut = rig.outerLever;

  double bladeForce(double fD) => fD * lIn / l;

  return [
    CombineLatestSource(
      name: 'Handle Force $suffix',
      unit: Unit.N,
      group: group,
      sources: [force],
      compute: (v) => v[0] * lOut / l,
    ),
    CombineLatestSource(
      name: 'Blade Force $suffix',
      unit: Unit.N,
      group: group,
      sources: [force],
      compute: (v) => bladeForce(v[0]),
    ),
    CombineLatestSource(
      name: 'Effective Force $suffix',
      unit: Unit.N,
      group: group,
      sources: [force, angle],
      compute: (v) => bladeForce(v[0]) * math.cos(_radians(v[1])),
    ),
    CombineLatestSource(
      name: 'Lateral Force $suffix',
      unit: Unit.N,
      group: group,
      sources: [force, angle],
      compute: (v) => bladeForce(v[0]) * math.sin(_radians(v[1])),
    ),
  ];
}

/// ω floor (rad/s) below which the blade is treated as not moving: power → 0,
/// efficiency suppressed (force-power §4 edge case).
const double _omegaFloor = 0.2;

/// Builds the per-sample power sources for one oarlock (force-power-model §2-4)
/// from its `Force`/`Angle`, the shared ω source [omega], the rig, and — for the
/// propulsion metrics — the boat [speedKmh] source. Speed-dependent sources are
/// omitted when [speedKmh] is null (no GPS speed yet).
List<DataSource> buildPowerSources({
  required DataSource force,
  required DataSource angle,
  required DataSource omega,
  required DataSource? speedKmh,
  required RigConfig rig,
  required String oarlockKey,
}) {
  final suffix = force.name.replaceFirst('Force ', '');
  final group = 'Force & Power ($oarlockKey)';
  final lIn = rig.innerLever;
  final l = rig.scullLength;
  final lOut = rig.outerLever;

  double handleForce(double fD) => fD * lOut / l;
  double bladeForce(double fD) => fD * lIn / l;

  final sources = <DataSource>[
    // P_oar = F_G · l_in · |ω|
    CombineLatestSource(
      name: 'Power $suffix',
      unit: Unit.W,
      group: group,
      sources: [force, omega],
      compute: (v) => handleForce(v[0]) * lIn * v[1].abs(),
    ),
  ];

  if (speedKmh == null) return sources;

  double bladeSpeed(double omegaValue) => lOut * omegaValue.abs();
  double alongBoat(double angleDeg, double speedKmhValue) =>
      (speedKmhValue / 3.6) * math.cos(_radians(angleDeg));

  return sources..addAll([
    // P_prop = F_B · cosθ · v_boat
    CombineLatestSource(
      name: 'Propulsion Power $suffix',
      unit: Unit.W,
      group: group,
      sources: [force, angle, speedKmh],
      alignedCount: 2,
      compute: (v) =>
          bladeForce(v[0]) * math.cos(_radians(v[1])) * (v[2] / 3.6),
    ),
    // v_slip = l_out·|ω| − v_boat·cosθ
    CombineLatestSource(
      name: 'Blade Slip $suffix',
      unit: Unit.mps,
      group: group,
      sources: [omega, angle, speedKmh],
      alignedCount: 2,
      compute: (v) => bladeSpeed(v[0]) - alongBoat(v[1], v[2]),
    ),
    // η_blade = v_boat·cosθ / (l_out·|ω|), clamped [0,1]·100
    CombineLatestSource(
      name: 'Blade Efficiency $suffix',
      unit: Unit.pct,
      group: group,
      sources: [omega, angle, speedKmh],
      alignedCount: 2,
      compute: (v) {
        if (v[0].abs() < _omegaFloor) return 0;
        return (alongBoat(v[1], v[2]) / bladeSpeed(v[0])).clamp(0.0, 1.0) * 100;
      },
    ),
  ]);
}
