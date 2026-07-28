import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/readiness_card.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_model.dart';
import 'package:rudertelemetrie_mobile_app/providers/bluetooth_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_manager.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';

/// Stands in for the real manager, whose device list only fills from a live
/// radio.
class _FakeBluetooth extends BluetoothProviderModel {
  List<ConnectedDevice> _devices = const [];

  @override
  List<ConnectedDevice> get connectedDevices => _devices;

  void connectDevice(String id) {
    _devices = [..._devices, ConnectedDevice(id: id, name: 'RowingBoat')];
    notifyListeners();
  }
}

Widget _card(
  DataSourceProviderModel sources,
  BoatConfig config,
  DashboardModel dashboard,
  BluetoothProviderModel bluetooth,
) => MultiProvider(
  providers: [
    ChangeNotifierProvider<DataSourceProviderModel>.value(value: sources),
    ChangeNotifierProvider<BoatConfig>.value(value: config),
    ChangeNotifierProvider<DashboardModel>.value(value: dashboard),
    ChangeNotifierProvider<BluetoothProviderModel>.value(value: bluetooth),
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
  late _FakeBluetooth bluetooth;

  setUp(() {
    sources = DataSourceProviderModel();
    config = BoatConfig();
    dashboard = DashboardModel();
    bluetooth = _FakeBluetooth();
  });

  void connectOarlock(int index) => sources.registry.register(
    PushDataSource(name: 'Force $index', unit: Unit.N, group: 'Oarlock $index'),
  );

  testWidgets('says nothing is connected before an oarlock appears', (
    tester,
  ) async {
    await tester.pumpWidget(_card(sources, config, dashboard, bluetooth));

    expect(find.text('None connected'), findsOneWidget);
    expect(find.text('No oarlocks'), findsOneWidget);
  });

  testWidgets('never denies a link the devices screen would show', (
    tester,
  ) async {
    await tester.pumpWidget(_card(sources, config, dashboard, bluetooth));

    bluetooth.connectDevice('AA:BB:CC:DD:1A:2B');
    await tester.pump();

    expect(find.text('None connected'), findsNothing);
    expect(find.text('Waiting for data'), findsOneWidget);
  });

  testWidgets('counts the oarlocks once their force arrives', (tester) async {
    bluetooth.connectDevice('AA:BB:CC:DD:1A:2B');
    await tester.pumpWidget(_card(sources, config, dashboard, bluetooth));

    connectOarlock(1);
    await tester.pump();

    expect(find.text('1 connected'), findsOneWidget);
  });

  testWidgets('counts connected oarlocks', (tester) async {
    connectOarlock(1);
    connectOarlock(2);
    await tester.pumpWidget(_card(sources, config, dashboard, bluetooth));

    expect(find.text('2 connected'), findsOneWidget);
  });

  testWidgets('flags an oarlock with no rig, before the user is on the water', (
    tester,
  ) async {
    connectOarlock(1);
    await tester.pumpWidget(_card(sources, config, dashboard, bluetooth));

    expect(find.text('Needs setup'), findsOneWidget);
  });

  testWidgets('settles once every connected oarlock is rigged', (tester) async {
    connectOarlock(1);
    config.setRig('Oarlock 1', BoatConfig.defaultRig);
    await tester.pumpWidget(_card(sources, config, dashboard, bluetooth));

    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Needs setup'), findsNothing);
  });

  testWidgets('names the preset the dashboard will open on', (tester) async {
    await dashboard.load();
    await tester.pumpWidget(_card(sources, config, dashboard, bluetooth));

    expect(find.text(DashboardModel.defaultPresetName), findsOneWidget);
  });
}
