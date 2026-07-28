import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/keep_screen_awake.dart';
import 'package:rudertelemetrie_mobile_app/components/notice_presenter.dart';
import 'package:rudertelemetrie_mobile_app/components/screen_orientation_lock.dart';
import 'package:rudertelemetrie_mobile_app/components/recording_lifecycle_guard.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/notifications_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/orientation_settings_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/recording_settings_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/bluetooth_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/boat_config_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/force_calibration_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/force_sources_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/power_sources_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/recording_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/session_store_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/stroke_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/speed_settings_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/screens//home_screen.dart';
import 'package:rudertelemetrie_mobile_app/utils/startup_util.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        notificationsProvider,
        speedSettingsProvider,
        orientationSettingsProvider,
        dashboardProvider,
        dataSourceProvider,
        sessionStoreProvider,
        recordingSettingsProvider,
        boatConfigProvider,
        forceCalibrationsProvider,
        recordingProvider,
        forceSourcesProvider,
        strokeSettingsProvider,
        strokeEngineProvider,
        forceCalibrationSessionProvider,
        powerSourcesProvider,
        visualizerProvider,
        bluetoothProvider,
      ],
      child: const Application(),
    ),
  );
}

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  @override
  void initState() {
    super.initState();
    initializeBluetooth(context);
    recoverInterruptedSessions(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = getTheme();

    return MaterialApp(
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      theme: theme.toApproximateMaterialTheme(),
      builder: (_, child) => FTheme(
        data: theme,
        child: FToaster(
          child: NoticePresenter(
            child: RecordingLifecycleGuard(
              child: ScreenOrientationLock(
                child: KeepScreenAwake(child: FTooltipGroup(child: child!)),
              ),
            ),
          ),
        ),
      ),
      // Each screen owns its own FScaffold; nesting one here double-padded Home.
      home: const Home(),
    );
  }
}
