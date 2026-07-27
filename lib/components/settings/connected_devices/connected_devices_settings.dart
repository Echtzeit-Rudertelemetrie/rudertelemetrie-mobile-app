import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/bluetooth_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_manager.dart';

/// Bluetooth status, the connected devices and what can be done about them:
/// rescan, disconnect, forget. Every control here acts — nothing is decorative.
class ConnectedDevicesSettings extends StatefulWidget {
  const ConnectedDevicesSettings({super.key});

  @override
  State<StatefulWidget> createState() => ConnectedDevicesSettingsState();
}

class ConnectedDevicesSettingsState extends State<ConnectedDevicesSettings> {
  late BluetoothManager _manager;
  late BluetoothState _state;
  late List<ConnectedDevice> _connectedDevices;

  StreamSubscription<BluetoothState>? _stateSubscription;
  StreamSubscription<List<ConnectedDevice>>? _devicesSubscription;

  @override
  void initState() {
    super.initState();
    _manager = context.read<BluetoothProviderModel>().manager;
    _state = _manager.state;
    _connectedDevices = _manager.connectedDevices;

    _stateSubscription = _manager.onStateChange.listen(
      (state) => setState(() => _state = state),
    );
    _devicesSubscription = _manager.onConnectedDevicesChange.listen(
      (devices) => setState(() => _connectedDevices = devices),
    );
  }

  @override
  void dispose() {
    // Cancel before super.dispose(): a callback firing on a defunct State
    // throws.
    _stateSubscription?.cancel();
    _devicesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 10,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Bluetooth'),
          Text(_stateLabel, style: const TextStyle(color: Colors.white70)),
        ],
      ),
      if (_connectedDevices.isEmpty)
        const _EmptyState()
      else
        FTileGroup.builder(
          label: const Text('Devices'),
          count: _connectedDevices.length,
          tileBuilder: (context, index) =>
              _deviceTile(_connectedDevices[index]),
        ),
      FButton(
        variant: FButtonVariant.outline,
        onPress: _manager.rescan,
        child: const Text('Scan for devices'),
      ),
    ],
  );

  String get _stateLabel => switch (_state) {
    BluetoothState.unknown => 'Checking…',
    BluetoothState.unsupported => 'Not supported',
    BluetoothState.disabled => 'Off',
    BluetoothState.active => 'Searching',
    BluetoothState.connected => 'Connected',
    BluetoothState.failed => 'Connected, no data',
  };

  FTileMixin _deviceTile(ConnectedDevice device) => FTile(
    prefix: const Icon(FIcons.bluetooth),
    title: Text(device.name),
    subtitle: Text(_deviceDetail(device)),
    suffix: const Icon(FIcons.chevronRight),
    onPress: () => _showActions(device),
  );

  String _deviceDetail(ConnectedDevice device) {
    final sources = context
        .read<DataSourceProviderModel>()
        .registry
        .all
        .where((s) => s.name.endsWith('(${_tag(device.id)})'))
        .length;
    final signal = device.rssi == null ? 'signal —' : '${device.rssi} dBm';
    return '$signal · $sources source${sources == 1 ? '' : 's'}';
  }

  /// Mirrors the suffix `BluetoothStreamHandler` appends to every source name.
  String _tag(String deviceId) {
    final compact = deviceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return compact.length <= 4
        ? compact
        : compact.substring(compact.length - 4);
  }

  void _showActions(ConnectedDevice device) => showFSheet(
    context: context,
    side: FLayout.btt,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            device.name,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '${device.id}\n${_deviceDetail(device)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FButton(
            variant: FButtonVariant.outline,
            onPress: () {
              Navigator.pop(sheetContext);
              _manager.disconnect(device.id);
            },
            child: const Text('Disconnect'),
          ),
          const SizedBox(height: 8),
          FButton(
            variant: FButtonVariant.destructive,
            onPress: () {
              Navigator.pop(sheetContext);
              _manager.forget(device.id);
            },
            child: const Text('Forget'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        const Text(
          'No devices connected.',
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 4),
        const Text(
          'Power on the boat and scan.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    ),
  );
}
