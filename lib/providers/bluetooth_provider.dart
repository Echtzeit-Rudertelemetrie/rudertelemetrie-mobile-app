import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_manager.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';

class BluetoothProviderModel extends ChangeNotifier {
  final BluetoothManager _manager;

  BluetoothProviderModel({AppNotifications? notifications})
    : _manager = BluetoothManager(notifications: notifications);

  BluetoothManager get manager => _manager;

  @override
  void dispose() {
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
