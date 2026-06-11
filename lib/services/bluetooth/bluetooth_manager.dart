import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_stream_handler.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';

enum BluetoothState { unknown, unsupported, disabled, active, connected, failed }

class ConnectedDevice {
  final String id;
  final String name;

  ConnectedDevice({required this.id, required this.name});
}

class BluetoothManager {
  final StreamController<BluetoothState> _stateStreamController = StreamController();

  final List<ConnectedDevice> _connectedDevices = [];
  final StreamController<List<ConnectedDevice>> _connectedDevicesStreamController = StreamController();

  DataSourceRegistry? _dataSourceRegistry;

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  Stream<BluetoothState> get onStateChange => _stateStreamController.stream;

  Stream<List<ConnectedDevice>> get onConnectedDevicesChange => _connectedDevicesStreamController.stream;

  Future<void> initialize(DataSourceRegistry dataSourceRegistry) async {
    _dataSourceRegistry = dataSourceRegistry;

    await checkStatus();

    await _startScan();
  }

  Future<void> checkStatus() async {
    if (!await FlutterBluePlus.isSupported) {
      _updateState(BluetoothState.unsupported);
    }

    FlutterBluePlus.setLogLevel(LogLevel.warning);

    _adapterStateSubscription ??= _subscribeToAdapterState();
    _scanResultsSubscription ??= _subscribeToScanResults();

    FlutterBluePlus.cancelWhenScanComplete(_scanResultsSubscription!);
  }

  StreamSubscription<BluetoothAdapterState> _subscribeToAdapterState() {
    return FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      _updateState(state == BluetoothAdapterState.on ? BluetoothState.active : BluetoothState.disabled);
    });
  }

  StreamSubscription<List<ScanResult>> _subscribeToScanResults() {
    return FlutterBluePlus.onScanResults.listen((results) async {
      if (results.isEmpty) return;

      ScanResult r = results.last;

      r.device.connect(autoConnect: true, mtu: null, license: License.free);

      await r.device.connectionState.where((val) => val == BluetoothConnectionState.connected).first;

      _updateState(BluetoothState.connected);

      final device = ConnectedDevice(id: r.device.remoteId.str, name: r.device.advName);

      _connectedDevices.add(device);

      if (!kIsWeb && Platform.isAndroid) {
        await r.device.requestMtu(512);
      }
    });
  }

  Future<void> createDataSource(BluetoothDevice device) async {
    final registry = _dataSourceRegistry;
    if (registry == null) {
      _updateState(BluetoothState.failed);
      return;
    }

    final notify = await findNotifyCharacteristic(device);

    if (notify == null) {
      _updateState(BluetoothState.failed);
      return;
    }

    await notify.setNotifyValue(true);

    final handler = BluetoothStreamHandler(dataSourceRegistry: registry);

    final valueSubscription = notify.onValueReceived.listen(handler.onPacket);

    final connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        handler.dispose();
      }
    });

    device.cancelWhenDisconnected(valueSubscription);
    device.cancelWhenDisconnected(connectionSubscription);
  }

  Future<BluetoothCharacteristic?> findNotifyCharacteristic(BluetoothDevice device) async {
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

    return notify;
  }

  Future<void> _startScan() async {
    await FlutterBluePlus.startScan(withNames: ["RowingBoat-BLE"]);
  }

  void _updateState(BluetoothState state) {
    _stateStreamController.sink.add(state);
  }
}
