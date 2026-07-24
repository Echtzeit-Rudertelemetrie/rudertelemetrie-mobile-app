import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/packet_reassembler.dart';

void main() {
  const frameSize = BluetoothPacket.packetSize; // 36

  List<int> frame(int fill) => List<int>.filled(frameSize, fill);

  test('ignores a partial notification', () {
    final frames = <List<int>>[];
    final r = PacketReassembler(frames.add);

    r.addFragment(frame(7).sublist(0, 20));

    expect(frames, isEmpty);
  });

  test('passes through a single full-size notification (large MTU)', () {
    final frames = <List<int>>[];
    final r = PacketReassembler(frames.add);

    r.addFragment(frame(3));

    expect(frames, [frame(3)]);
  });

  test('passes through several consecutive notifications', () {
    final frames = <List<int>>[];
    final r = PacketReassembler(frames.add);

    for (final packet in [frame(1), frame(2), frame(3)]) {
      r.addFragment(packet);
    }

    expect(frames, [frame(1), frame(2), frame(3)]);
  });

  test('drops a truncated value without corrupting the next notification', () {
    final frames = <List<int>>[];
    final r = PacketReassembler(frames.add);

    r.addFragment(frame(9).sublist(0, frameSize - 20));
    r.addFragment(frame(5));

    expect(frames, [frame(5)]);
  });

  test('ignores empty fragments', () {
    final frames = <List<int>>[];
    final r = PacketReassembler(frames.add);

    r.addFragment([]);
    r.addFragment(frame(4));

    expect(frames, [frame(4)]);
  });
}
