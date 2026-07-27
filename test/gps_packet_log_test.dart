import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/gps_packet_log.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';

List<int> _boatFrame({
  required int sequence,
  double latitude = 47.123456,
  double longitude = 9.345678,
  bool valid = true,
  int satellites = 8,
}) {
  final data = ByteData(BluetoothPacket.packetSize);
  data.setUint32(0, sequence & 0x0FFFFFFF, Endian.little);
  data.setInt32(4, (latitude * 1e6).round(), Endian.little);
  data.setInt32(8, (longitude * 1e6).round(), Endian.little);
  data.setUint8(16, satellites);
  data.setUint8(17, valid ? 1 : 0);
  return data.buffer.asUint8List();
}

BoatPacket _boatPacket({
  required int sequence,
  double latitude = 47.123456,
  double longitude = 9.345678,
  bool valid = true,
  int satellites = 8,
}) {
  final frame = _boatFrame(
    sequence: sequence,
    latitude: latitude,
    longitude: longitude,
    valid: valid,
    satellites: satellites,
  );
  return BluetoothPacket.decode(frame) as BoatPacket;
}

void main() {
  late List<String> lines;
  late GpsPacketLog log;
  late DateTime start;

  setUp(() {
    lines = [];
    log = GpsPacketLog(deviceId: 'AB12', write: lines.add);
    start = DateTime(2026, 7, 27, 10);
  });

  test('announces the first boat packet and the first valid fix', () {
    log.record(_boatPacket(sequence: 1), start);

    expect(lines.first, contains('first boat packet'));
    expect(lines[1], contains('first valid fix 47.123456/9.345678, 8 sats'));
  });

  test('reports a gap between boat packets', () {
    log.record(_boatPacket(sequence: 1), start);
    log.record(
      _boatPacket(sequence: 2),
      start.add(const Duration(milliseconds: 900)),
    );

    expect(lines, anyElement(contains('gap of 900 ms')));
  });

  test('counts a repeated fix once, so the summary shows the true fix rate', () {
    for (var i = 0; i < 64; i++) {
      // 12.5 Hz packets carrying a position that only moves once per second.
      final at = start.add(Duration(milliseconds: i * 80));
      log.record(
        _boatPacket(sequence: i + 1, latitude: 47.123456 + (i ~/ 13) * 4e-5),
        at,
      );
    }

    final summary = lines.last;
    expect(summary, contains('64 packets/5.0s'));
    expect(summary, contains('12.7 Hz'));
    expect(summary, contains('position updates 5'));
    expect(summary, contains('sats 8'));
  });

  test('counts packets missing from the sequence', () {
    log.record(_boatPacket(sequence: 1), start);
    log.record(_boatPacket(sequence: 5), start.add(const Duration(seconds: 6)));

    expect(lines.last, contains('missed 3'));
  });

  test('dumps the decoded fields and raw bytes when no fix is ever valid', () {
    final frame = _boatFrame(sequence: 2, valid: false);
    log.record(_boatPacket(sequence: 1, valid: false), start);
    log.record(
      BluetoothPacket.decode(frame) as BoatPacket,
      start.add(const Duration(seconds: 6)),
      rawFrame: frame,
    );

    expect(lines.last, contains('valid 0'));
    expect(lines.last, contains('no valid fix yet'));
    expect(lines.last, contains('last 47.123456/9.345678 sats 8'));
    expect(lines.last, contains('raw 02000000 000ccf02 8e9a8e00'));
  });
}
