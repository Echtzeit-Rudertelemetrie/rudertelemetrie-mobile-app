import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';

final _baseForce = RegExp(r'^Force \d');

/// The stable keys (source groups, e.g. `Oarlock 1 (1A2B)`) of every oarlock
/// with a live `Force` source in [registry]. Used to key rig config and to list
/// configurable oarlocks in the setup UI.
Set<String> connectedOarlockKeys(DataSourceRegistry registry) => {
  for (final source in registry.all)
    if (_baseForce.hasMatch(source.name) && source.group != null) source.group!,
};

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
