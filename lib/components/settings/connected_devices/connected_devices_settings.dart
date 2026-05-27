import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rudertelemetrie_mobile_app/services/ble/packet_loss_analyzer.dart';

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

    FlutterBluePlus.setLogLevel(LogLevel.warning);

    _adapterStateSubscription ??= FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
        if (state == BluetoothAdapterState.on) {
          _state = BluetoothState.active;
        } else {
          _state = BluetoothState.disabled;
        }
      });

    _scanResultsSubscription ??= FlutterBluePlus.onScanResults.listen((results) async {
      if (results.isNotEmpty) {
        ScanResult r = results.last;
        print('${r.device.remoteId}: "${r.advertisementData.advName}" found!');

        r.device.connect(autoConnect: true, mtu: null, license: License.free);

        await r.device.connectionState.where((val) => val == BluetoothConnectionState.connected).first;

        if (!kIsWeb && Platform.isAndroid) {
          await r.device.requestMtu(512);
        }

        await _runPacketLossTest(r.device);
      }
    },
    onError: (e) => print(e));

    FlutterBluePlus.cancelWhenScanComplete(_scanResultsSubscription!);

    await FlutterBluePlus.startScan(withNames: ["RowingBoat-BLE"]);
  }

  Future<void> _runPacketLossTest(BluetoothDevice device) async {
    final services = await device.discoverServices();
    BluetoothCharacteristic? notify;

    for (final service in services) {
      for (final c in service.characteristics) {
        if (c.properties.notify) {
          notify = c;
          break;
        }
      }
      if (notify != null) break;
    }

    if (notify == null) {
      print('[PacketLoss] No notify characteristic found');
      return;
    }

    print('[PacketLoss] Listening for 10s on ${notify.uuid}...');

    final analyzer = PacketLossAnalyzer();
    await notify.setNotifyValue(true);

    final stopwatch = Stopwatch()..start();
    final subscription = notify.onValueReceived.listen(analyzer.onPacket);
    device.cancelWhenDisconnected(subscription);

    await Future.delayed(const Duration(seconds: 10));

    stopwatch.stop();
    await subscription.cancel();
    analyzer.printReport(stopwatch.elapsed);
  }

  @override void dispose() {
    super.dispose();

    _adapterStateSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) => Text(_state.toString());
}