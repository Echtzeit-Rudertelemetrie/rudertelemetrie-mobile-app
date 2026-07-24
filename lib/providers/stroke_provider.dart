import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_engine.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_settings.dart';

final strokeSettingsProvider = ChangeNotifierProvider<StrokeSettings>(
  create: (_) => StrokeSettings(),
);

/// Eager: the engine must observe oarlock sources and drive the recording
/// session's auto-start/stop from startup. Not watched by a widget, so a plain
/// [Provider] suffices.
final strokeEngineProvider = Provider<StrokeEngine>(
  lazy: false,
  create: (context) => StrokeEngine(
    registry: context.read<DataSourceProviderModel>().registry,
    settings: context.read<StrokeSettings>(),
    session: context.read<RecordingSession>(),
  ),
  dispose: (_, engine) => engine.dispose(),
);
