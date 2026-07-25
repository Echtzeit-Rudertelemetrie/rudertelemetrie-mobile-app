import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_stream_handler.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';

void main() {
  test('registers one force and angle stream without protocol sensor IDs', () {
    final registry = DataSourceRegistry();
    final handler = BluetoothStreamHandler(
      dataSourceRegistry: registry,
      deviceId: 'AA:BB:CC:D4:79',
    );
    final packet = ByteData(BluetoothPacket.packetSize)
      ..setUint32(0, 1 << 28, Endian.little);

    handler.onData(packet.buffer.asUint8List());

    expect(
      registry.all.map((source) => source.name),
      unorderedEquals(['Force (D479)', 'Angle (D479)']),
    );

    handler.dispose();
  });

  test('paces the 8 samples across the packet duration', () async {
    final registry = DataSourceRegistry();
    final handler = BluetoothStreamHandler(
      dataSourceRegistry: registry,
      deviceId: 'device',
    );
    final packet = ByteData(BluetoothPacket.packetSize)
      ..setUint32(0, 1 << 28, Endian.little);

    handler.onData(packet.buffer.asUint8List());
    final force = registry.get('Force (vice)')!;
    final received = <Object>[];
    final subscription = force.data.listen(received.add);

    expect(received, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(received.length, inInclusiveRange(1, 7));

    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(received, hasLength(8));

    await subscription.cancel();
    handler.dispose();
  });

  test(
    'drops duplicate packets and keeps timestamps monotonic after restart',
    () async {
      final registry = DataSourceRegistry();
      final sequences = <int>[];
      final handler = BluetoothStreamHandler(
        dataSourceRegistry: registry,
        deviceId: 'test-device',
        onOarlockPacket: sequences.add,
      );

      List<int> packet(int sequence) {
        final data = ByteData(BluetoothPacket.packetSize)
          ..setUint32(0, (1 << 28) | sequence, Endian.little);
        return data.buffer.asUint8List();
      }

      handler.onData(packet(1000));
      handler.onData(packet(1000)); // radio retry
      handler.onData(packet(1001));
      handler.onData(packet(999)); // late packet
      handler.onData(packet(1)); // sender reboot

      expect(sequences, [1000, 1001, 1]);
      handler.dispose();
    },
  );
}
