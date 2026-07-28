import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_manager.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';

class BluetoothProviderModel extends ChangeNotifier {
  final BluetoothManager _manager;

  StreamSubscription<List<ConnectedDevice>>? _devicesSubscription;
  Set<String> _deviceIds = {};

  BluetoothProviderModel({AppNotifications? notifications})
    : _manager = BluetoothManager(notifications: notifications) {
    _devicesSubscription = _manager.onConnectedDevicesChange.listen(
      _onDevicesChanged,
    );
  }

  BluetoothManager get manager => _manager;

  List<ConnectedDevice> get connectedDevices => _manager.connectedDevices;

  /// Only a change to the device set is worth a rebuild. The same stream also
  /// carries the ten-second signal-strength poll, which would otherwise redraw
  /// every listener for a number none of them show.
  void _onDevicesChanged(List<ConnectedDevice> devices) {
    final ids = {for (final device in devices) device.id};
    if (setEquals(ids, _deviceIds)) return;
    _deviceIds = ids;
    notifyListeners();
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _manager.dispose();
    super.dispose();
  }
}

ChangeNotifierProvider<BluetoothProviderModel> bluetoothProvider =
    ChangeNotifierProvider(
      create: (context) => BluetoothProviderModel(
        notifications: context.read<AppNotifications>(),
      ),
    );
