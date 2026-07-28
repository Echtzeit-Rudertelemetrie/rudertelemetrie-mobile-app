import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/readiness_card.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_model.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';

Widget _card(
  DataSourceProviderModel sources,
  BoatConfig config,
  DashboardModel dashboard,
) => MultiProvider(
  providers: [
    ChangeNotifierProvider<DataSourceProviderModel>.value(value: sources),
    ChangeNotifierProvider<BoatConfig>.value(value: config),
    ChangeNotifierProvider<DashboardModel>.value(value: dashboard),
  ],
  child: MaterialApp(
    builder: (_, child) =>
        FTheme(data: FThemes.neutral.dark.desktop, child: child!),
    home: const Scaffold(body: ReadinessCard()),
  ),
);

void main() {
  late DataSourceProviderModel sources;
  late BoatConfig config;
  late DashboardModel dashboard;

  setUp(() {
    sources = DataSourceProviderModel();
    config = BoatConfig();
    dashboard = DashboardModel();
  });

  void connectOarlock(int index) => sources.registry.register(
    PushDataSource(name: 'Force $index', unit: Unit.N, group: 'Oarlock $index'),
  );

  testWidgets('says nothing is connected before an oarlock appears', (
    tester,
  ) async {
    await tester.pumpWidget(_card(sources, config, dashboard));

    expect(find.text('None connected'), findsOneWidget);
    expect(find.text('No oarlocks'), findsOneWidget);
  });

  testWidgets('counts connected oarlocks', (tester) async {
    connectOarlock(1);
    connectOarlock(2);
    await tester.pumpWidget(_card(sources, config, dashboard));

    expect(find.text('2 connected'), findsOneWidget);
  });

  testWidgets('flags an oarlock with no rig, before the user is on the water', (
    tester,
  ) async {
    connectOarlock(1);
    await tester.pumpWidget(_card(sources, config, dashboard));

    expect(find.text('Needs setup'), findsOneWidget);
  });

  testWidgets('settles once every connected oarlock is rigged', (tester) async {
    connectOarlock(1);
    config.setRig('Oarlock 1', BoatConfig.defaultRig);
    await tester.pumpWidget(_card(sources, config, dashboard));

    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Needs setup'), findsNothing);
  });

  testWidgets('names the preset the dashboard will open on', (tester) async {
    await dashboard.load();
    await tester.pumpWidget(_card(sources, config, dashboard));

    expect(find.text(DashboardModel.defaultPresetName), findsOneWidget);
  });
}
