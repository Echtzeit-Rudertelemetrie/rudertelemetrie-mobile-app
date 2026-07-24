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
}
