import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibrations.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_settings.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

final recordingProvider = ChangeNotifierProvider<RecordingSession>(
  // Eager so the session (and its derived sources) exist from startup rather
  // than only once a widget first watches it. The constructor's source
  // registration notifies via a deferred microtask (registerDeferred), so it is
  // safe even though provider `create` runs during the build phase.
  lazy: false,
  create: (context) => RecordingSession(
    registry: context.read<DataSourceProviderModel>().registry,
    store: context.read<SessionStore>(),
    notifications: context.read<AppNotifications>(),
    settings: context.read<RecordingSettings>(),
    calibrations: context.read<ForceCalibrations>(),
  ),
);
