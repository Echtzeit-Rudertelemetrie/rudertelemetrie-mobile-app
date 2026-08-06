import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibrations.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oar_side_detection.dart';

final _baseForce = RegExp(r'^Force \d');

/// The stable keys (source groups, e.g. `Oarlock 1 (1A2B)`) of every oarlock
/// with a live `Force` source in [registry]. Used to key rig config and to list
/// configurable oarlocks in the setup UI.
Set<String> connectedOarlockKeys(DataSourceRegistry registry) => {
  for (final source in registry.all)
    if (_baseForce.hasMatch(source.name) && source.group != null) source.group!,
};

/// Forgets an oarlock everywhere it is remembered: rig, seat, force
/// calibration, and any accumulated side detection.
///
/// Geometry and sensor calibration live in separate stores because they have
/// independent lifetimes — a rig survives recalibrating a cell, and a
/// calibration survives re-rigging a boat. That makes "remove this oarlock" a
/// single intent spanning both, and one that has to be named in one place or
/// the half nobody remembered outlives the device forever.
void forgetOarlock(
  String oarlockKey, {
  required BoatConfig config,
  required ForceCalibrations calibrations,
  OarSideDetection? sideDetection,
}) {
  config.removeOarlock(oarlockKey);
  calibrations.removeCalibration(oarlockKey);
  sideDetection?.forget(oarlockKey);
}

/// Connected oarlocks whose rig is missing or unusable. Their force and power
/// sources are not registered, which is otherwise indistinguishable from a
/// broken app — the dashboard says so explicitly instead.
List<String> oarlocksNeedingRig(
  DataSourceRegistry registry,
  BoatConfig config,
) => [
  for (final key in connectedOarlockKeys(registry))
    if (!(config.rigFor(key)?.isValid ?? false)) key,
]..sort();
