import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';

/// Validates fixed-size [BluetoothPacket.packetSize] BLE notifications.
///
/// FlutterBluePlus exposes one callback per complete GATT notification; ATT/L2CAP
/// fragmentation is reassembled below the application API. The firmware sends
/// exactly one MeasurementPack per notification. Rejecting partial values keeps
/// one dropped/truncated notification from permanently shifting every following
/// packet boundary.
class PacketReassembler {
  static const _frameSize = BluetoothPacket.packetSize;

  final void Function(List<int> frame) onFrame;
  PacketReassembler(this.onFrame);

  void addFragment(List<int> value) {
    if (value.length != _frameSize) return;
    onFrame(List.of(value));
  }
}
