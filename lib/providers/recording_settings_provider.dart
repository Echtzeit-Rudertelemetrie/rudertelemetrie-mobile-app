import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_settings.dart';

/// Eager so [RecordingSession] can read it during its own eager creation.
final recordingSettingsProvider = ChangeNotifierProvider<RecordingSettings>(
  lazy: false,
  create: (_) => RecordingSettings(store: FileRecordingSettingsStore())..load(),
);
