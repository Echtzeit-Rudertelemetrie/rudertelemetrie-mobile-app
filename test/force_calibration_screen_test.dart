import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/screens/force_calibration_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/force_calibration_setup_screen.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration_session.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibrations.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';

const _key = 'Oarlock 1';

Widget _wrap({
  required DataSourceProviderModel sources,
  required ForceCalibrations calibrations,
  required Widget home,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<DataSourceProviderModel>.value(value: sources),
    ChangeNotifierProvider<ForceCalibrations>.value(value: calibrations),
    ChangeNotifierProvider<ForceCalibrationSession>(
      create: (context) => ForceCalibrationSession(
        calibrations: context.read<ForceCalibrations>(),
      ),
    ),
  ],
  child: MaterialApp(
    builder: (_, child) =>
        FTheme(data: FThemes.neutral.dark.desktop, child: child!),
    home: home,
  ),
);

void main() {
  late DataSourceProviderModel sources;
  late ForceCalibrations calibrations;

  setUp(() {
    sources = DataSourceProviderModel();
    calibrations = ForceCalibrations();
    sources.registry.register(
      PushDataSource(name: 'Force 1', unit: Unit.N, group: _key),
    );
  });

  tearDown(() => calibrations.dispose());

  group('setup list', () {
    testWidgets('says an uncalibrated oarlock is not measuring newtons', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          sources: sources,
          calibrations: calibrations,
          home: const ForceCalibrationSetupScreen(),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Not calibrated'), findsOneWidget);
      expect(find.text('Calibrate'), findsOneWidget);
    });

    testWidgets('offers recalibration once a calibration is stored', (
      tester,
    ) async {
      calibrations.setCalibration(
        _key,
        ForceCalibration.fit(
          zeroRaw: 1000,
          loadedRaw: 11000,
          massKg: 20,
          at: DateTime(2026, 7, 27),
        )!,
      );

      await tester.pumpWidget(
        _wrap(
          sources: sources,
          calibrations: calibrations,
          home: const ForceCalibrationSetupScreen(),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Calibrated 2026-07-27'), findsOneWidget);
      expect(find.text('Recalibrate'), findsOneWidget);
    });

    testWidgets('says nothing to calibrate with no oarlock connected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          sources: DataSourceProviderModel(),
          calibrations: calibrations,
          home: const ForceCalibrationSetupScreen(),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Connect an oarlock'), findsOneWidget);
    });
  });

  group('guided flow', () {
    testWidgets('opens on the unload step and pauses zero tracking', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          sources: sources,
          calibrations: calibrations,
          home: const ForceCalibrationScreen(oarlockKey: _key),
        ),
      );
      await tester.pump();

      expect(find.text('Unload the oarlock'), findsOneWidget);
      expect(calibrations.isTrackingPaused, isTrue);
    });

    testWidgets('popping back resumes zero tracking', (tester) async {
      await tester.pumpWidget(
        _wrap(
          sources: sources,
          calibrations: calibrations,
          home: const ForceCalibrationSetupScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Calibrate'));
      await tester.pumpAndSettle();
      expect(calibrations.isTrackingPaused, isTrue);

      await tester.tap(find.byIcon(FIcons.arrowLeft));
      await tester.pumpAndSettle();

      expect(calibrations.isTrackingPaused, isFalse);
    });

    // A route replaced from elsewhere disposes the screen without a pop, so
    // PopScope never fires. Without the dispose backstop, force would silently
    // stop being drift-corrected for the rest of the outing.
    testWidgets('a disposal that is not a pop still resumes tracking', (
      tester,
    ) async {
      final session = ForceCalibrationSession(calibrations: calibrations);
      addTearDown(session.dispose);

      Widget host(Widget home) => MultiProvider(
        providers: [
          ChangeNotifierProvider<DataSourceProviderModel>.value(value: sources),
          ChangeNotifierProvider<ForceCalibrations>.value(value: calibrations),
          ChangeNotifierProvider<ForceCalibrationSession>.value(value: session),
        ],
        child: MaterialApp(
          builder: (_, child) =>
              FTheme(data: FThemes.neutral.dark.desktop, child: child!),
          home: home,
        ),
      );

      await tester.pumpWidget(
        host(const ForceCalibrationScreen(oarlockKey: _key)),
      );
      await tester.pump();
      expect(calibrations.isTrackingPaused, isTrue);

      await tester.pumpWidget(host(const ForceCalibrationSetupScreen()));
      await tester.pumpAndSettle();

      expect(calibrations.isTrackingPaused, isFalse);
    });
  });
}
