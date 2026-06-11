import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/bluetooth_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_manager.dart';

class ConnectedDevicesSettings extends StatefulWidget {
  const ConnectedDevicesSettings({super.key});

  @override
  State<StatefulWidget> createState() => ConnectedDevicesSettingsState();
}

class ConnectedDevicesSettingsState extends State<ConnectedDevicesSettings> {
  BluetoothState _state = BluetoothState.unknown;
  StreamSubscription<BluetoothState>? _bluetoothStateSubscription;

  @override
  void initState() {
    super.initState();

    final bluetoothManager = context.read<BluetoothProviderModel>().manager;

    _bluetoothStateSubscription = bluetoothManager.onStateChange.listen((newState) {
      setState(() {
        _state = newState;
      });
    });
  }

  @override void dispose() {
    super.dispose();

    _bluetoothStateSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) => Column(spacing: 10, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("Bluetooth"),
        Text(_state.name.toString()),
      ],),
  ],);
}