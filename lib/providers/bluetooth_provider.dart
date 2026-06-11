import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_manager.dart';

class BluetoothProviderModel extends ChangeNotifier {
  final BluetoothManager _manager = BluetoothManager();

  BluetoothManager get manager => _manager;
}

ChangeNotifierProvider<BluetoothProviderModel> bluetoothProvider =
    ChangeNotifierProvider(create: (_) => BluetoothProviderModel());