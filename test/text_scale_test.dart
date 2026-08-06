import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/screens/boat_setup_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/recording_settings_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/stroke_settings_screen.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_settings.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oar_side_detection.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_settings.dart';

/// Wraps [home] with the app's theme at the largest system text scale, on the
/// narrowest phone the app targets.
Widget _atMaxTextScale(Widget home, List<SingleChildWidget> providers) =>
    MultiProvider(
      providers: providers,
      child: MaterialApp(
        builder: (context, child) => FTheme(
          data: FThemes.neutral.dark.desktop,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
        ),
        home: home,
      ),
    );

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  Future<void> expectNoOverflow(
    WidgetTester tester,
    Widget home,
    List<SingleChildWidget> providers,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_atMaxTextScale(home, providers));
    await tester.pump();

    expect(tester.takeException(), isNull);
  }

  testWidgets('stroke settings survives a 2x text scale at 320 dp', (
    tester,
  ) async {
    await expectNoOverflow(tester, const StrokeSettingsScreen(), [
      ChangeNotifierProvider<StrokeSettings>(create: (_) => StrokeSettings()),
    ]);
  });

  testWidgets('recording settings survives a 2x text scale at 320 dp', (
    tester,
  ) async {
    await expectNoOverflow(tester, const RecordingSettingsScreen(), [
      ChangeNotifierProvider<RecordingSettings>(
        create: (_) => RecordingSettings(),
      ),
    ]);
  });

  testWidgets('boat setup survives a 2x text scale at 320 dp with an eight', (
    tester,
  ) async {
    final sources = DataSourceProviderModel();
    sources.registry.register(
      PushDataSource(name: 'Force 1', unit: Unit.N, group: 'Oarlock 1'),
    );
    final config = BoatConfig()..setBoatClass(BoatClass.eight);

    await expectNoOverflow(tester, const BoatSetupScreen(), [
      ChangeNotifierProvider<DataSourceProviderModel>.value(value: sources),
      ChangeNotifierProvider<BoatConfig>.value(value: config),
      ChangeNotifierProvider<OarSideDetection>(
        create: (_) => OarSideDetection(config: config),
      ),
    ]);
  });
}
