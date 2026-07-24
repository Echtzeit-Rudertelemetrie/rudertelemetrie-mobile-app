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
