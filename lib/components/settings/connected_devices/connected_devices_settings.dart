import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/bluetooth_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_manager.dart';
import 'package:rudertelemetrie_mobile_app/components/status_card.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

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
      _BluetoothStatus(label: _stateLabel, tone: _stateTone),
      if (_connectedDevices.isEmpty)
        const _EmptyState()
      else
        FTileGroup.builder(
          label: const Text('Connected'),
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

  /// The colour of the dot beside the state. Nothing here is a control — the
  /// manager connects to what it finds on its own, so this reports rather than
  /// offers.
  StatusTone get _stateTone => switch (_state) {
    BluetoothState.connected => StatusTone.ok,
    BluetoothState.active || BluetoothState.unknown => StatusTone.neutral,
    BluetoothState.unsupported ||
    BluetoothState.disabled ||
    BluetoothState.failed => StatusTone.warning,
  };

  String get _stateLabel => switch (_state) {
    BluetoothState.unknown => 'Checking…',
    BluetoothState.unsupported => 'Not supported',
    BluetoothState.disabled => 'Off',
    BluetoothState.active => 'Searching',
    BluetoothState.connected => 'Connected',
    BluetoothState.failed => 'Connected, no data',
  };

  FTileMixin _deviceTile(ConnectedDevice device) => FTile(
    prefix: const _ConnectedBadge(),
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
            style: const TextStyle(color: AppPalette.label, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '${device.id}\n${_deviceDetail(device)}',
            style: const TextStyle(color: AppPalette.faintLabel, fontSize: 12),
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

/// The Bluetooth adapter's own state, as a dot and a word.
class _BluetoothStatus extends StatelessWidget {
  final String label;
  final StatusTone tone;

  const _BluetoothStatus({required this.label, required this.tone});

  Color get _color => switch (tone) {
    StatusTone.ok => AppPalette.ok,
    StatusTone.warning => AppPalette.warning,
    StatusTone.neutral => AppPalette.faintLabel,
  };

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text('Bluetooth'),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: _color, fontSize: AppTypeScale.label),
          ),
        ],
      ),
    ],
  );
}

/// Green ring on a connected device: the list is only ever connected devices,
/// so the badge confirms rather than distinguishes.
class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: AppPalette.ok.withAlpha(40),
      shape: BoxShape.circle,
    ),
    child: const Icon(FIcons.bluetooth, size: 16, color: AppPalette.ok),
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
          style: TextStyle(color: AppPalette.faintLabel),
        ),
        const SizedBox(height: 4),
        const Text(
          'Power on the boat and scan.',
          style: TextStyle(color: AppPalette.disabledLabel, fontSize: 12),
        ),
      ],
    ),
  );
}
