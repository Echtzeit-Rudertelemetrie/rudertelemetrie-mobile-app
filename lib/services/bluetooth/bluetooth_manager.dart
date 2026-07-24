import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_stream_handler.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';

enum BluetoothState {
  unknown,
  unsupported,
  disabled,
  active,
  connected,
  failed,
}

class ConnectedDevice {
  final String id;
  final String name;

  ConnectedDevice({required this.id, required this.name});
}

class BluetoothManager {
  final StreamController<BluetoothState> _stateStreamController =
      StreamController.broadcast();

  final List<ConnectedDevice> _connectedDevices = [];
  final StreamController<List<ConnectedDevice>>
  _connectedDevicesStreamController = StreamController.broadcast();

  BluetoothState _state = BluetoothState.unknown;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  DataSourceRegistry? _dataSourceRegistry;

  final Map<String, _DeviceConnection> _connections = {};

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  BluetoothState get state => _state;

  Stream<BluetoothState> get onStateChange => _stateStreamController.stream;

  List<ConnectedDevice> get connectedDevices => _connectedDevices;

  Stream<List<ConnectedDevice>> get onConnectedDevicesChange =>
      _connectedDevicesStreamController.stream;

  Future<void> initialize(DataSourceRegistry dataSourceRegistry) async {
    _dataSourceRegistry = dataSourceRegistry;

    await checkStatus();

    await _startScanIfReady();
  }

  Future<void> checkStatus() async {
    if (!await FlutterBluePlus.isSupported) {
      _updateState(BluetoothState.unsupported);
      return;
    }

    FlutterBluePlus.setLogLevel(LogLevel.warning);

    _adapterStateSubscription ??= _subscribeToAdapterState();
    _scanResultsSubscription ??= _subscribeToScanResults();

    FlutterBluePlus.cancelWhenScanComplete(_scanResultsSubscription!);
  }

  StreamSubscription<BluetoothAdapterState> _subscribeToAdapterState() {
    return FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      _adapterState = state;
      final isOn = state == BluetoothAdapterState.on;
      _updateState(isOn ? BluetoothState.active : BluetoothState.disabled);
      if (isOn) _startScanIfReady();
    });
  }

  StreamSubscription<List<ScanResult>> _subscribeToScanResults() {
    return FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        _handleScanResult(r);
      }
    });
  }

  void _handleScanResult(ScanResult result) {
    final device = result.device;
    if (_connections.containsKey(device.remoteId.str)) return;
    _connectDevice(device);
  }

  void _connectDevice(BluetoothDevice device) {
    final connection = _DeviceConnection(device);
    _connections[device.remoteId.str] = connection;

    connection.connectionSubscription = device.connectionState.listen(
      (state) => _onConnectionState(connection, state),
    );

    device
        .connect(autoConnect: true, mtu: null, license: License.free)
        .catchError((_) => _forgetDevice(connection));
  }

  void _onConnectionState(
    _DeviceConnection connection,
    BluetoothConnectionState state,
  ) {
    switch (state) {
      case BluetoothConnectionState.connected:
        _onDeviceConnected(connection);
      case BluetoothConnectionState.disconnected:
        _onDeviceDisconnected(connection);
      default:
        break;
    }
  }

  Future<void> _onDeviceConnected(_DeviceConnection connection) async {
    final device = connection.device;

    _updateState(BluetoothState.connected);
    _addConnectedDevice(
      ConnectedDevice(id: device.remoteId.str, name: device.advName),
    );

    if (connection.handler != null || connection.isSettingUp) return;
    connection.isSettingUp = true;

    if (!kIsWeb && Platform.isAndroid) {
      await device.requestMtu(512);
    }

    await _registerDataSource(connection);
    connection.isSettingUp = false;
  }

  void _onDeviceDisconnected(_DeviceConnection connection) {
    connection.teardownStream();
    _removeConnectedDeviceWithId(connection.device.remoteId.str);
    // The connection entry and its connectionState listener stay alive so
    // autoConnect reconnection re-runs [_onDeviceConnected].
  }

  Future<void> _registerDataSource(_DeviceConnection connection) async {
    final registry = _dataSourceRegistry;
    if (registry == null) {
      _updateState(BluetoothState.failed);
      return;
    }

    final notify = await findNotifyCharacteristic(connection.device);

    if (notify == null) {
      _updateState(BluetoothState.failed);
      return;
    }

    await notify.setNotifyValue(true);

    final handler = BluetoothStreamHandler(
      dataSourceRegistry: registry,
      deviceId: connection.device.remoteId.str,
    );
    connection.handler = handler;
    connection.valueSubscription = notify.onValueReceived.listen(
      handler.onData,
    );
  }

  void _forgetDevice(_DeviceConnection connection) {
    connection.dispose();
    _connections.remove(connection.device.remoteId.str);
    _removeConnectedDeviceWithId(connection.device.remoteId.str);
  }

  /// UUID of the firmware's `MeasurementPack` notify characteristic
  /// (service a1b2c3d4-0001-…, characteristic a1b2c3d4-0002-…).
  static final Guid _measurementCharacteristic = Guid(
    'a1b2c3d4-0002-4a2b-9c3d-1234567890ab',
  );

  Future<BluetoothCharacteristic?> findNotifyCharacteristic(
    BluetoothDevice device,
  ) async {
    final services = await device.discoverServices();

    BluetoothCharacteristic? firstNotify;
    for (final service in services) {
      for (final c in service.characteristics) {
        if (c.characteristicUuid == _measurementCharacteristic) return c;
        final p = c.properties;
        firstNotify ??= (p.notify || p.indicate) ? c : null;
      }
    }

    return firstNotify;
  }

  Future<void> _startScanIfReady() async {
    if (_adapterState != BluetoothAdapterState.on) return;
    if (FlutterBluePlus.isScanningNow) return;
    await FlutterBluePlus.startScan(withNames: ["RowingBoat"]);
  }

  void _updateState(BluetoothState state) {
    _state = state;
    _stateStreamController.sink.add(state);
  }

  void _addConnectedDevice(ConnectedDevice device) {
    if (_connectedDevices.any((d) => d.id == device.id)) return;
    _connectedDevices.add(device);
    _connectedDevicesStreamController.sink.add(_connectedDevices);
  }

  void _removeConnectedDeviceWithId(String id) {
    _connectedDevices.removeWhere((device) => device.id == id);
    _connectedDevicesStreamController.sink.add(_connectedDevices);
  }
}

/// Per-device connection state. Kept alive across reconnections; only the
/// stream setup (notify subscription + handler) is torn down on disconnect and
/// rebuilt on the next connect.
class _DeviceConnection {
  final BluetoothDevice device;

  StreamSubscription<BluetoothConnectionState>? connectionSubscription;
  StreamSubscription<List<int>>? valueSubscription;
  BluetoothStreamHandler? handler;
  bool isSettingUp = false;

  _DeviceConnection(this.device);

  void teardownStream() {
    valueSubscription?.cancel();
    valueSubscription = null;
    handler?.dispose();
    handler = null;
    isSettingUp = false;
  }

  void dispose() {
    teardownStream();
    connectionSubscription?.cancel();
    connectionSubscription = null;
  }
}
