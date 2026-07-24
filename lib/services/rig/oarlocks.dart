import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';

final _baseForce = RegExp(r'^Force \d');

/// The stable keys (source groups, e.g. `Oarlock 1 (1A2B)`) of every oarlock
/// with a live `Force` source in [registry]. Used to key rig config and to list
/// configurable oarlocks in the setup UI.
Set<String> connectedOarlockKeys(DataSourceRegistry registry) => {
      for (final source in registry.all)
        if (_baseForce.hasMatch(source.name) && source.group != null)
          source.group!,
    };
