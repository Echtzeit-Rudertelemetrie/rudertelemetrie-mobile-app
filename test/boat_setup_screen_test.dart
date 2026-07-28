import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/screens/boat_setup_screen.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibrations.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';

Widget _screen(
  DataSourceProviderModel sources,
  BoatConfig config, {
  ForceCalibrations? calibrations,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<DataSourceProviderModel>.value(value: sources),
    ChangeNotifierProvider<BoatConfig>.value(value: config),
    ChangeNotifierProvider<ForceCalibrations>.value(
      value: calibrations ?? ForceCalibrations(),
    ),
  ],
  child: MaterialApp(
    builder: (_, child) =>
        FTheme(data: FThemes.neutral.dark.desktop, child: child!),
    home: const BoatSetupScreen(),
  ),
);

void main() {
  late DataSourceProviderModel sources;
  late BoatConfig config;

  setUp(() {
    sources = DataSourceProviderModel();
    config = BoatConfig();
    for (var i = 1; i <= 2; i++) {
      sources.registry.register(
        PushDataSource(name: 'Force $i', unit: Unit.N, group: 'Oarlock $i'),
      );
    }
  });

  testWidgets('renders an eight on a narrow phone without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    config.setBoatClass(BoatClass.eight);
    await tester.pumpWidget(_screen(sources, config));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('flags two oarlocks assigned the same seat and side', (
    tester,
  ) async {
    // Tall enough that both oarlock sections are built at once.
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    config.assignSlot('Oarlock 1', const SeatSlot(seat: 1, side: OarSide.port));
    config.assignSlot('Oarlock 2', const SeatSlot(seat: 1, side: OarSide.port));

    await tester.pumpWidget(_screen(sources, config));
    await tester.pump();

    expect(find.textContaining('already holds this seat'), findsNWidgets(2));
  });

  /// Chips have to shrink-wrap their label. A `Container.alignment` swells to
  /// whatever width the parent allows, which inside a [Wrap] is the whole row —
  /// and every chip lands on a line of its own, turning both rows into a
  /// stack of full-width buttons.
  testWidgets('lays chips out along a row rather than one per line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    config.setBoatClass(BoatClass.double_);
    await tester.pumpWidget(_screen(sources, config));
    await tester.pump();

    double rowOf(Finder chip) => tester.getCenter(chip).dy;

    // Boat class pills.
    expect(rowOf(find.text('1x')), rowOf(find.text('2x')));

    // Seat chips, then side chips, of the first oarlock.
    expect(rowOf(find.text('1').first), rowOf(find.text('2').first));
    expect(rowOf(find.text('port').first), rowOf(find.text('both').first));

    // And a chip is no wider than its label needs.
    expect(tester.getSize(find.text('1x')).width, lessThan(100));
  });

  testWidgets('unassigns an oarlock', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    config.assignSlot('Oarlock 1', const SeatSlot(seat: 2, side: OarSide.both));
    await tester.pumpWidget(_screen(sources, config));
    await tester.pump();

    await tester.tap(find.text('Unassign'));
    await tester.pump();

    expect(config.slotFor('Oarlock 1'), isNull);
  });

  testWidgets('removes a stale oarlock that is no longer connected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    config.setRig('Oarlock 9', BoatConfig.defaultRig);
    config.assignSlot('Oarlock 9', const SeatSlot(seat: 1, side: OarSide.both));

    await tester.pumpWidget(_screen(sources, config));
    await tester.pump();

    expect(find.textContaining('Oarlock 9 (not connected)'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pump();

    expect(config.rigFor('Oarlock 9'), isNull);
    expect(config.slotFor('Oarlock 9'), isNull);
  });

  testWidgets('removing an oarlock forgets its force calibration too', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final calibrations = ForceCalibrations();
    addTearDown(calibrations.dispose);
    calibrations.setCalibration(
      'Oarlock 9',
      ForceCalibration.fit(
        zeroRaw: 1000,
        loadedRaw: 11000,
        massKg: 20,
        at: DateTime(2026, 7, 27),
      )!,
    );
    config.setRig('Oarlock 9', BoatConfig.defaultRig);
    config.assignSlot('Oarlock 9', const SeatSlot(seat: 1, side: OarSide.both));

    await tester.pumpWidget(
      _screen(sources, config, calibrations: calibrations),
    );
    await tester.pump();

    expect(find.textContaining('Oarlock 9 (not connected)'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pump();

    // Left behind, the calibration would be silently reapplied to whatever
    // oarlock next claimed that key.
    expect(calibrations.calibrationFor('Oarlock 9').isCalibrated, isFalse);
    expect(calibrations.knownKeys, isNot(contains('Oarlock 9')));
  });

  group('conflict detection', () {
    test('both overlaps a single-sided assignment on the same seat', () {
      config.assignSlot('a', const SeatSlot(seat: 1, side: OarSide.both));
      config.assignSlot('b', const SeatSlot(seat: 1, side: OarSide.port));
      expect(config.conflictingSlotKeys, {'a', 'b'});
    });

    test('opposite sides on one seat are fine', () {
      config.assignSlot('a', const SeatSlot(seat: 1, side: OarSide.port));
      config.assignSlot('b', const SeatSlot(seat: 1, side: OarSide.starboard));
      expect(config.conflictingSlotKeys, isEmpty);
    });

    test('different seats never conflict', () {
      config.assignSlot('a', const SeatSlot(seat: 1, side: OarSide.both));
      config.assignSlot('b', const SeatSlot(seat: 2, side: OarSide.both));
      expect(config.conflictingSlotKeys, isEmpty);
    });
  });
}
