import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';

/// Reassembles fixed-size [BluetoothPacket.packetSize] frames from BLE
/// notification fragments.
///
/// When the negotiated ATT MTU is small the firmware splits each 84-byte packet
/// across several notifications (e.g. 20+20+20+20+4); a large MTU delivers all
/// 84 bytes in one. A fragment shorter than the largest one seen marks a packet
/// boundary, letting the reassembler self-align when it starts mid-packet or
/// drops a fragment: a buffer that is not exactly one frame at a boundary is
/// discarded rather than decoded.
class PacketReassembler {
  static const _frameSize = BluetoothPacket.packetSize;

  final void Function(List<int> frame) onFrame;
  final List<int> _buffer = [];
  int _maxFragment = 0;

  PacketReassembler(this.onFrame);

  void addFragment(List<int> fragment) {
    if (fragment.isEmpty) return;
    if (fragment.length > _maxFragment) _maxFragment = fragment.length;

    _buffer.addAll(fragment);

    final atBoundary = fragment.length < _maxFragment;
    if (!atBoundary && _buffer.length < _frameSize) return;

    if (_buffer.length == _frameSize) onFrame(List.of(_buffer));
    _buffer.clear();
  }
}
