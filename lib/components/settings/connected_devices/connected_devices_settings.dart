import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BluetoothState {
  unknown,
  unsupported,
  disabled,
  active,
}

class ConnectedDevicesSettings extends StatefulWidget {
  const ConnectedDevicesSettings({super.key});

  @override
  State<StatefulWidget> createState() => ConnectedDevicesSettingsState();
}

class ConnectedDevicesSettingsState extends State<ConnectedDevicesSettings> {
  BluetoothState _state = BluetoothState.unknown;

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  @override
  void initState() {
    super.initState();

    checkStatus();
  }

  Future<void> checkStatus() async {
    if (!await FlutterBluePlus.isSupported) {
      _state = BluetoothState.unsupported;
    }

    _adapterStateSubscription ??= FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
        if (state == BluetoothAdapterState.on) {
          _state = BluetoothState.active;
        } else {
          _state = BluetoothState.disabled;
        }
      });

    _scanResultsSubscription ??= FlutterBluePlus.onScanResults.listen((results) {
      if (results.isNotEmpty) {
        ScanResult r = results.last;
        print('${r.device.remoteId}: "${r.advertisementData.advName}" found!');
      }
    },
    onError: (e) => print(e));

    FlutterBluePlus.cancelWhenScanComplete(_scanResultsSubscription!);

    await FlutterBluePlus.startScan();
  }

  @override void dispose() {
    super.dispose();

    _adapterStateSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) => Text(_state.toString());
}