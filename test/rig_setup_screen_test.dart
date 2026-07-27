import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/screens/rig_setup_screen.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';

Widget _screen(DataSourceProviderModel sources, BoatConfig config) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DataSourceProviderModel>.value(value: sources),
        ChangeNotifierProvider<BoatConfig>.value(value: config),
      ],
      child: MaterialApp(
        builder: (_, child) =>
            FTheme(data: FThemes.neutral.dark.desktop, child: child!),
        home: const RigSetupScreen(),
      ),
    );

const _lin = ValueKey('Oarlock 1.lin');
const _scullLength = ValueKey('Oarlock 1.L');

void main() {
  late DataSourceProviderModel sources;
  late BoatConfig config;

  setUp(() {
    sources = DataSourceProviderModel();
    config = BoatConfig();
    sources.registry.register(
      PushDataSource(name: 'Force 1', unit: Unit.N, group: 'Oarlock 1'),
    );
  });

  // Regression: the fields used to be prefilled with the example rig while
  // nothing was stored, so an oarlock the user had "already set up" stayed
  // unconfigured and the dashboard kept asking for a rig.
  testWidgets('starts empty and says the rig is not set', (tester) async {
    await tester.pumpWidget(_screen(sources, config));
    await tester.pump();

    expect(_textOf(tester, _lin), '');
    expect(_textOf(tester, _scullLength), '');
    expect(find.textContaining('Not set'), findsOneWidget);
    expect(config.rigFor('Oarlock 1'), isNull);
  });

  testWidgets('stores the rig once both lengths are entered', (tester) async {
    await tester.pumpWidget(_screen(sources, config));
    await tester.pump();

    await tester.enterText(find.byKey(_lin), '0.9');
    await tester.pump(const Duration(seconds: 1));
    expect(config.rigFor('Oarlock 1'), isNull); // L still missing

    await tester.enterText(find.byKey(_scullLength), '2.9');
    await tester.pump(const Duration(seconds: 1));

    expect(config.rigFor('Oarlock 1')?.innerLever, 0.9);
    expect(config.rigFor('Oarlock 1')?.scullLength, 2.9);
    expect(find.textContaining('Saved'), findsOneWidget);
  });

  testWidgets('applies the example rig in one tap', (tester) async {
    await tester.pumpWidget(_screen(sources, config));
    await tester.pump();

    await tester.tap(find.textContaining('Use example rig'));
    await tester.pumpAndSettle();

    expect(config.rigFor('Oarlock 1'), BoatConfig.defaultRig);
    expect(find.textContaining('Use example rig'), findsNothing);
  });

  testWidgets('rejects an inner lever that reaches the scull length', (
    tester,
  ) async {
    config.setRig(
      'Oarlock 1',
      const RigConfig(innerLever: 0.88, scullLength: 2.88),
    );
    await tester.pumpWidget(_screen(sources, config));
    await tester.pump();

    await tester.enterText(find.byKey(_lin), '3');
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Must be less than L'), findsOneWidget);
    expect(config.rigFor('Oarlock 1')?.innerLever, 0.88); // never committed
  });

  testWidgets('shows a rig that loads after the screen is built', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(sources, config));
    await tester.pump();

    config.setRig(
      'Oarlock 1',
      const RigConfig(innerLever: 0.88, scullLength: 2.88),
    );
    await tester.pump();

    expect(_textOf(tester, _lin), '0.88');
    expect(_textOf(tester, _scullLength), '2.88');
  });
}

String _textOf(WidgetTester tester, Key key) => tester
    .widget<TextField>(
      find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
    )
    .controller!
    .text;
