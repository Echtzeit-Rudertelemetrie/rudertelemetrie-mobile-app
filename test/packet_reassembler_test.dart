import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/packet_reassembler.dart';

void main() {
  const frameSize = BluetoothPacket.packetSize;

  List<int> frame(int fill) => List<int>.filled(frameSize, fill);

  List<List<int>> fragmentsOf(List<int> data, int chunk) => [
        for (var i = 0; i < data.length; i += chunk)
          data.sublist(i, (i + chunk).clamp(0, data.length)),
      ];

  test('reassembles a 20-byte-fragmented frame (MTU 23)', () {
    final frames = <List<int>>[];
    final r = PacketReassembler(frames.add);

    for (final f in fragmentsOf(frame(7), 20)) {
      r.addFragment(f);
    }

    expect(frames, [frame(7)]);
  });

  test('passes through a single full-size notification (large MTU)', () {
    final frames = <List<int>>[];
    final r = PacketReassembler(frames.add);

    r.addFragment(frame(3));

    expect(frames, [frame(3)]);
  });

  test('reassembles several consecutive frames', () {
    final frames = <List<int>>[];
    final r = PacketReassembler(frames.add);

    for (final packet in [frame(1), frame(2), frame(3)]) {
      for (final f in fragmentsOf(packet, 20)) {
        r.addFragment(f);
      }
    }

    expect(frames, [frame(1), frame(2), frame(3)]);
  });

  test('drops a partial frame and re-aligns after a lost fragment', () {
    final frames = <List<int>>[];
    final r = PacketReassembler(frames.add);

    // First packet loses a fragment, so it never reaches frameSize (short).
    // Drop a non-tail fragment: the surviving short tail marks the boundary
    // that lets the reassembler re-align on the next packet.
    final broken = fragmentsOf(frame(9), 20)..removeAt(0);
    for (final f in broken) {
      r.addFragment(f);
    }
    // Next packet arrives intact.
    for (final f in fragmentsOf(frame(5), 20)) {
      r.addFragment(f);
    }

    expect(frames, [frame(5)]);
  });

  test('ignores empty fragments', () {
    final frames = <List<int>>[];
    final r = PacketReassembler(frames.add);

    r.addFragment([]);
    for (final f in fragmentsOf(frame(4), 20)) {
      r.addFragment(f);
    }

    expect(frames, [frame(4)]);
  });
}
