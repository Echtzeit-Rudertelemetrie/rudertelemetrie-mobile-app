import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rudertelemetrie_mobile_app/models/telemetry_quality.dart';
import 'package:rudertelemetrie_mobile_app/models/speed_settings_model.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_stream_handler.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';

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

  /// Last known signal strength in dBm, or null before one has been read.
  final int? rssi;

  ConnectedDevice({required this.id, required this.name, this.rssi});

  ConnectedDevice withRssi(int? value) =>
      ConnectedDevice(id: id, name: name, rssi: value);
}

class BluetoothManager {
  /// Where a packet-loss spike is announced. Optional so tests and any headless
  /// use can construct a manager without the notification queue.
  final AppNotifications? notifications;

  late final TelemetryQualityMonitor telemetryQuality = TelemetryQualityMonitor(
    onLossSpike: _reportLossSpike,
  );

  BluetoothManager({this.notifications});

  static const _deviceName = 'RowingBoat';

  /// Discovery runs as a duty cycle rather than continuously: a permanent scan
  /// is a significant battery drain over a multi-hour outing.
  static const _scanWindow = Duration(seconds: 10);
  static const _scanInterval = Duration(seconds: 60);
  static const _rssiInterval = Duration(seconds: 10);

  final StreamController<BluetoothState> _stateStreamController =
      StreamController.broadcast();

  final List<ConnectedDevice> _connectedDevices = [];
  final StreamController<List<ConnectedDevice>>
  _connectedDevicesStreamController = StreamController.broadcast();

  final StreamController<String> _errorStreamController =
      StreamController.broadcast();
  final StreamController<ConnectedDevice> _deviceConnectedController =
      StreamController.broadcast();
  final StreamController<ConnectedDevice> _deviceLostController =
      StreamController.broadcast();

  BluetoothState _state = BluetoothState.unknown;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _supported = true;
  bool _dataSetupFailed = false;

  DataSourceRegistry? _dataSourceRegistry;
  SpeedSettingsModel? _speedSettings;

  final Map<String, _DeviceConnection> _connections = {};

  /// Devices the user asked to forget. Skipped on discovery until [rescan],
  /// otherwise the next scan window would immediately reconnect them.
  final Set<String> _forgotten = {};

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  Timer? _scanCycleTimer;
  Timer? _rssiTimer;

  BluetoothState get state => _state;

  Stream<BluetoothState> get onStateChange => _stateStreamController.stream;

  List<ConnectedDevice> get connectedDevices => _connectedDevices;

  Stream<List<ConnectedDevice>> get onConnectedDevicesChange =>
      _connectedDevicesStreamController.stream;

  /// Human-readable Bluetooth failures, for surfacing to the user.
  Stream<String> get onError => _errorStreamController.stream;

  Stream<ConnectedDevice> get onDeviceConnected =>
      _deviceConnectedController.stream;

  Stream<ConnectedDevice> get onDeviceLost => _deviceLostController.stream;

  Future<void> initialize(
    DataSourceRegistry dataSourceRegistry,
    SpeedSettingsModel speedSettings,
  ) async {
    _dataSourceRegistry = dataSourceRegistry;
    _speedSettings = speedSettings;
    await checkStatus();
    await _syncScanning();
  }

  Future<void> checkStatus() async {
    _supported = await FlutterBluePlus.isSupported;
    if (!_supported) {
      _publishState();
      return;
    }

    FlutterBluePlus.setLogLevel(LogLevel.warning);

    // One long-lived results subscription: tying it to a scan window (via
    // `cancelWhenScanComplete`) would end discovery permanently after the first
    // window closes.
    _adapterStateSubscription ??= _subscribeToAdapterState();
    _scanResultsSubscription ??= _subscribeToScanResults();
    _publishState();
  }

  StreamSubscription<BluetoothAdapterState> _subscribeToAdapterState() {
    return FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      _adapterState = state;
      if (state != BluetoothAdapterState.on) _dataSetupFailed = false;
      _publishState();
      unawaited(_syncScanning());
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
    final id = device.remoteId.str;
    if (_forgotten.contains(id) || _connections.containsKey(id)) return;
    _lastSeenRssi[id] = result.rssi;
    _connectDevice(device);
  }

  final Map<String, int> _lastSeenRssi = {};

  void _connectDevice(BluetoothDevice device) {
    final connection = _DeviceConnection(device);
    _connections[device.remoteId.str] = connection;

    connection.connectionSubscription = device.connectionState.listen(
      (state) => _onConnectionState(connection, state),
    );

    device
        .connect(autoConnect: true, mtu: null, license: License.free)
        .catchError((Object error) {
          _reportError('Could not connect to ${_label(device)}', error);
          _forgetDevice(connection);
        });
  }

  String _label(BluetoothDevice device) =>
      device.advName.isEmpty ? device.remoteId.str : device.advName;

  void _reportError(String message, Object error) {
    debugPrint('$message: $error');
    _errorStreamController.sink.add(message);
  }

  /// Only a burst gets a toast. Steady reception is the assumption, and a lone
  /// dropped packet is absorbed by the pipeline — announcing it would train the
  /// rower to ignore the one message that matters.
  void _reportLossSpike(int lostPackets) => notifications?.alert(
    'Weak sensor signal',
    detail:
        '$lostPackets packets lost in the last '
        '${TelemetryQualityMonitor.spikeWindow.inSeconds} s.',
  );

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

    _addConnectedDevice(
      ConnectedDevice(
        id: device.remoteId.str,
        name: _label(device),
        rssi: _lastSeenRssi[device.remoteId.str],
      ),
    );
    await _syncScanning();
    _startRssiPolling();

    if (connection.handler != null || connection.isSettingUp) return;
    connection.isSettingUp = true;

    try {
      if (!kIsWeb && Platform.isAndroid) {
        await device.requestMtu(512);
      }
      await _registerDataSource(connection);
    } catch (error) {
      _reportError('Could not read data from ${_label(device)}', error);
      _markDataSetupFailed();
    } finally {
      connection.isSettingUp = false;
    }
  }

  void _onDeviceDisconnected(_DeviceConnection connection) {
    connection.teardownStream();
    _removeConnectedDeviceWithId(connection.device.remoteId.str);
    unawaited(_syncScanning());
    // The connection entry and its connectionState listener stay alive so
    // autoConnect reconnection re-runs [_onDeviceConnected].
  }

  Future<void> _registerDataSource(_DeviceConnection connection) async {
    final registry = _dataSourceRegistry;
    final speedSettings = _speedSettings;
    if (registry == null || speedSettings == null) {
      _markDataSetupFailed();
      return;
    }

    final notify = await findNotifyCharacteristic(connection.device);

    if (notify == null) {
      _reportError(
        'No measurement channel on ${_label(connection.device)}',
        StateError('no notify characteristic'),
      );
      _markDataSetupFailed();
      return;
    }

    await notify.setNotifyValue(true);
    _dataSetupFailed = false;
    _publishState();

    final deviceId = connection.device.remoteId.str;
    final handler = BluetoothStreamHandler(
      dataSourceRegistry: registry,
      speedSettings: speedSettings,
      deviceId: deviceId,
      onOarlockPacket: (sequence) =>
          telemetryQuality.recordPacket(deviceId, sequence),
      onInvalidPacket: () => telemetryQuality.recordInvalidPacket(deviceId),
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

  /// Scans only while nothing is connected, so an outing does not spend its
  /// battery on discovery. A disconnect restarts the cycle by itself.
  Future<void> _syncScanning() async {
    final wanted =
        _adapterState == BluetoothAdapterState.on && _connectedDevices.isEmpty;
    if (!wanted) {
      await stopScan();
      return;
    }
    await _startScanCycle();
  }

  Future<void> _startScanCycle() async {
    _scanCycleTimer ??= Timer.periodic(
      _scanInterval,
      (_) => unawaited(_scanWindowOnce()),
    );
    await _scanWindowOnce();
  }

  Future<void> _scanWindowOnce() async {
    if (_adapterState != BluetoothAdapterState.on) return;
    if (FlutterBluePlus.isScanningNow) return;
    try {
      await FlutterBluePlus.startScan(
        withNames: [_deviceName],
        timeout: _scanWindow,
      );
    } catch (error) {
      _reportError('Bluetooth scan could not be started', error);
    }
  }

  /// Ends the current scan window and the duty cycle behind it.
  Future<void> stopScan() async {
    _scanCycleTimer?.cancel();
    _scanCycleTimer = null;
    if (!FlutterBluePlus.isScanningNow) return;
    try {
      await FlutterBluePlus.stopScan();
    } catch (error) {
      _reportError('Bluetooth scan could not be stopped', error);
    }
  }

  /// Starts a discovery window immediately, regardless of the duty cycle, and
  /// gives forgotten devices another chance — asking to scan means asking to
  /// find everything.
  Future<void> rescan() async {
    _forgotten.clear();
    if (_adapterState != BluetoothAdapterState.on) return;
    await _startScanCycle();
  }

  /// Drops the connection but keeps the device discoverable, so autoConnect or
  /// the next scan window can bring it back.
  Future<void> disconnect(String deviceId) async {
    final connection = _connections[deviceId];
    if (connection == null) return;
    try {
      await connection.device.disconnect();
    } catch (error) {
      _reportError(
        'Could not disconnect ${connection.device.remoteId.str}',
        error,
      );
    }
  }

  /// Disconnects and stops trying: the device is ignored until [rescan].
  Future<void> forget(String deviceId) async {
    _forgotten.add(deviceId);
    await disconnect(deviceId);
    final connection = _connections[deviceId];
    if (connection != null) _forgetDevice(connection);
    await _syncScanning();
  }

  /// Signal strength only changes while connected, and scanning is off by then,
  /// so it is read from the link itself rather than from advertisements.
  void _startRssiPolling() {
    _rssiTimer ??= Timer.periodic(_rssiInterval, (_) => unawaited(_pollRssi()));
  }

  Future<void> _pollRssi() async {
    if (_connectedDevices.isEmpty) {
      _rssiTimer?.cancel();
      _rssiTimer = null;
      return;
    }
    var changed = false;
    for (var i = 0; i < _connectedDevices.length; i++) {
      final entry = _connectedDevices[i];
      final device = _connections[entry.id]?.device;
      if (device == null) continue;
      try {
        final rssi = await device.readRssi();
        if (rssi == entry.rssi) continue;
        _connectedDevices[i] = entry.withRssi(rssi);
        changed = true;
      } catch (_) {
        // A read failing is not worth a message; the last value stands.
      }
    }
    if (changed) _connectedDevicesStreamController.sink.add(_connectedDevices);
  }

  void _markDataSetupFailed() {
    _dataSetupFailed = true;
    _publishState();
  }

  /// The reported state always follows the live adapter and connection set —
  /// never the last event seen — so a disconnect cannot leave it on `connected`.
  BluetoothState get _derivedState {
    if (!_supported) return BluetoothState.unsupported;
    if (_adapterState == BluetoothAdapterState.unknown) {
      return BluetoothState.unknown;
    }
    if (_adapterState != BluetoothAdapterState.on) {
      return BluetoothState.disabled;
    }
    if (_dataSetupFailed) return BluetoothState.failed;
    return _connectedDevices.isEmpty
        ? BluetoothState.active
        : BluetoothState.connected;
  }

  void _publishState() {
    final next = _derivedState;
    if (next == _state) return;
    _state = next;
    _stateStreamController.sink.add(next);
  }

  void _addConnectedDevice(ConnectedDevice device) {
    if (_connectedDevices.any((d) => d.id == device.id)) return;
    _connectedDevices.add(device);
    _connectedDevicesStreamController.sink.add(_connectedDevices);
    _deviceConnectedController.sink.add(device);
    _publishState();
  }

  void _removeConnectedDeviceWithId(String id) {
    final index = _connectedDevices.indexWhere((device) => device.id == id);
    if (index == -1) return;
    final removed = _connectedDevices.removeAt(index);
    telemetryQuality.removeDevice(id);
    _connectedDevicesStreamController.sink.add(_connectedDevices);
    _deviceLostController.sink.add(removed);
    _publishState();
  }

  Future<void> dispose() async {
    telemetryQuality.dispose();
    _rssiTimer?.cancel();
    _rssiTimer = null;
    await stopScan();
    await _adapterStateSubscription?.cancel();
    await _scanResultsSubscription?.cancel();
    for (final connection in _connections.values) {
      connection.dispose();
    }
    _connections.clear();
    await _stateStreamController.close();
    await _connectedDevicesStreamController.close();
    await _errorStreamController.close();
    await _deviceConnectedController.close();
    await _deviceLostController.close();
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
