import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/bluetooth_stream_handler.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';

/// One 132-byte oarlock `MeasurementPack` with constant force/angle samples.
List<int> _oarlockFrame(int sensorId, int sequence) {
  final data = ByteData(BluetoothPacket.packetSize);
  data.setUint32(
    0,
    ((sensorId & 0x7) << 29) | (sequence & 0x1FFFFFFF),
    Endian.little,
  );
  for (var i = 0; i < 32; i++) {
    data.setUint16(4 + i * 2, 1000, Endian.little);
    data.setUint16(68 + i * 2, 2000, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  late DataSourceRegistry registry;
  late BluetoothStreamHandler handler;

  setUp(() {
    registry = DataSourceRegistry();
    handler = BluetoothStreamHandler(
      dataSourceRegistry: registry,
      deviceId: 'AA:BB:CC:DD:EE:01',
    );
  });

  tearDown(() => handler.dispose());

  DataSource sourceStartingWith(String prefix) =>
      registry.all.firstWhere((s) => s.name.startsWith(prefix));

  Future<List<Measurement>> collect(String prefix, void Function() feed) async {
    feed(); // registers the source on the first packet
    final source = sourceStartingWith(prefix);
    final received = <Measurement>[];
    final sub = source.data.listen(received.add);
    addTearDown(sub.cancel);
    feed();
    await pumpEventQueue();
    return received;
  }

  test(
    'anchors a large starting sequence number to the source start time',
    () async {
      var sequence = 1000000;
      final samples = await collect('Force 1', () {
        handler.onData(_oarlockFrame(1, sequence++));
      });

      final start = sourceStartingWith('Force 1').startTime;
      final offsets = samples.map(
        (m) => m.timestamp.difference(start).inMilliseconds,
      );

      // Second packet: 32 samples, 5 ms apart, starting one packet (160 ms) in.
      expect(offsets.first, 160);
      expect(offsets.last, 160 + 31 * 5);
    },
  );

  test('each oarlock is anchored independently', () async {
    handler.onData(_oarlockFrame(1, 500000));
    handler.onData(_oarlockFrame(2, 900000));

    final first = sourceStartingWith('Force 1');
    final second = sourceStartingWith('Force 2');
    final firstSamples = <Measurement>[];
    final secondSamples = <Measurement>[];
    final subs = [
      first.data.listen(firstSamples.add),
      second.data.listen(secondSamples.add),
    ];
    addTearDown(() {
      for (final s in subs) {
        s.cancel();
      }
    });

    handler.onData(_oarlockFrame(1, 500001));
    handler.onData(_oarlockFrame(2, 900001));
    await pumpEventQueue();

    expect(
      firstSamples.first.timestamp.difference(first.startTime).inMilliseconds,
      160,
    );
    expect(
      secondSamples.first.timestamp.difference(second.startTime).inMilliseconds,
      160,
    );
  });

  test('a sequence counter wrapping past 29 bits keeps advancing', () async {
    handler.onData(_oarlockFrame(1, 0x1FFFFFFF));
    final source = sourceStartingWith('Force 1');
    final samples = <Measurement>[];
    final sub = source.data.listen(samples.add);
    addTearDown(sub.cancel);

    handler.onData(_oarlockFrame(1, 0)); // wrapped
    await pumpEventQueue();

    expect(
      samples.first.timestamp.difference(source.startTime).inMilliseconds,
      160,
    );
  });
}
