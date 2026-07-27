import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/power_source_registrar.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_engine.dart';

/// Eager: the registrar wires the power/aggregate sources onto oarlocks + rig +
/// stroke events from startup. Not watched by a widget, so a plain [Provider].
final powerSourcesProvider = Provider<PowerSourceRegistrar>(
  lazy: false,
  create: (context) => PowerSourceRegistrar(
    registry: context.read<DataSourceProviderModel>().registry,
    config: context.read<BoatConfig>(),
    engine: context.read<StrokeEngine>(),
  ),
  dispose: (_, registrar) => registrar.dispose(),
);
