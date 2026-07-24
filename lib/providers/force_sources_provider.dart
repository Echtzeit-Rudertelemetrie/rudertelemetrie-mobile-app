import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/force_source_registrar.dart';

/// Eager: the registrar must observe the registry and rig config from startup so
/// force sources appear as soon as an oarlock connects and its rig is set. It is
/// not watched by any widget, so a plain [Provider] is enough.
final forceSourcesProvider = Provider<ForceSourceRegistrar>(
  lazy: false,
  create: (context) => ForceSourceRegistrar(
    registry: context.read<DataSourceProviderModel>().registry,
    config: context.read<BoatConfig>(),
  ),
  dispose: (_, registrar) => registrar.dispose(),
);
