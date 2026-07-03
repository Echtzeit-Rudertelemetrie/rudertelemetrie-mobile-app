import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/bluetooth_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_manager.dart';

class ConnectedDevicesSettings extends StatefulWidget {
  const ConnectedDevicesSettings({super.key});

  @override
  State<StatefulWidget> createState() => ConnectedDevicesSettingsState();
}

class ConnectedDevicesSettingsState extends State<ConnectedDevicesSettings> {
  late BluetoothState _state;
  StreamSubscription<BluetoothState>? _bluetoothStateSubscription;

  late List<ConnectedDevice> _connectedDevices;
  StreamSubscription<List<ConnectedDevice>>? _connectedDevicesSubscription;

  @override
  void initState() {
    super.initState();

    final bluetoothManager = context.read<BluetoothProviderModel>().manager;

    _state = bluetoothManager.state;

    _bluetoothStateSubscription = bluetoothManager.onStateChange.listen((newState) {
      setState(() {
        _state = newState;
      });
    });

    _connectedDevices = bluetoothManager.connectedDevices;

    _connectedDevicesSubscription = bluetoothManager.onConnectedDevicesChange.listen((newDevices) {
      setState(() {
        _connectedDevices = newDevices;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _bluetoothStateSubscription?.cancel();
    _connectedDevicesSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) => Column(
    spacing: 10,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text("Bluetooth"), Text(_state.name.toString())],
      ),
      FTileGroup.builder(
        label: const Text('Devices'),
        count: _connectedDevices.length,
        tileBuilder: (context, index) {
          final device = _connectedDevices[index];
          return FTile(
            prefix: const Icon(FIcons.bluetooth),
            title: Text(device.name),
            suffix: const Icon(FIcons.chevronRight),
          );
        },
      )
    ],
  );
}
