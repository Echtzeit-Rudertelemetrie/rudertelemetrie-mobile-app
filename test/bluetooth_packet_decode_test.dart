import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';

/// Byte-exact fixtures mirroring the firmware `MeasurementPack` (packed,
/// little-endian) as emitted by `rowing_boat`. Offsets derive from
/// [BluetoothPacket.samplesPerPacket] so the fixtures track the wire format.
const _forceRegionOffset = 4;
const _angleRegionOffset =
    _forceRegionOffset + BluetoothPacket.samplesPerPacket * 2;

class _PackBuilder {
  final ByteData _data = ByteData(BluetoothPacket.packetSize);

  _PackBuilder(int id, int sequence) {
    _data.setUint32(0, ((id & 0x7) << 29) | (sequence & 0x1FFFFFFF),
        Endian.little);
  }

  _PackBuilder u16(int offset, int value) {
    _data.setUint16(offset, value, Endian.little);
    return this;
  }

  _PackBuilder i32(int offset, int value) {
    _data.setInt32(offset, value, Endian.little);
    return this;
  }

  _PackBuilder i16(int offset, int value) {
    _data.setInt16(offset, value, Endian.little);
    return this;
  }

  _PackBuilder u8(int offset, int value) {
    _data.setUint8(offset, value);
    return this;
  }

  _PackBuilder f32(int offset, double value) {
    _data.setFloat32(offset, value, Endian.little);
    return this;
  }

  List<int> build() => _data.buffer.asUint8List();
}

void main() {
  test('returns null for undersized buffers', () {
    expect(
      BluetoothPacket.decode(List.filled(BluetoothPacket.packetSize - 1, 0)),
      isNull,
    );
  });

  test('splits id (top 3 bits) and 29-bit sequence from the header', () {
    final raw = _PackBuilder(3, 0x0ABCDEF).build();
    final packet = BluetoothPacket.decode(raw)!;

    expect(packet.sensorId, 3);
    expect(packet.sequenceNumber, 0x0ABCDEF);
  });

  test('decodes an oarlock packet (id 1..7) into force and angle samples', () {
    const n = BluetoothPacket.samplesPerPacket;
    final builder = _PackBuilder(2, 7);
    for (var i = 0; i < n; i++) {
      builder.u16(_forceRegionOffset + i * 2, 100 + i); // force region
      builder.u16(_angleRegionOffset + i * 2, 500 + i); // angle region
    }

    final packet = BluetoothPacket.decode(builder.build());

    expect(packet, isA<OarlockPacket>());
    final oarlock = packet as OarlockPacket;
    expect(oarlock.sensorId, 2);
    expect(oarlock.forces.length, n);
    expect(oarlock.angles.length, n);
    expect(oarlock.forces.first, 100);
    expect(oarlock.forces.last, 100 + n - 1);
    expect(oarlock.angles.first, 500);
    expect(oarlock.angles.last, 500 + n - 1);
  });

  test('decodes a boat packet (id 0) into GPS and IMU samples', () {
    final raw = _PackBuilder(0, 42)
        // GpsData in the force region
        .i32(_forceRegionOffset, 47123456) // lat * 1e6
        .i32(_forceRegionOffset + 4, 9345678) // lon * 1e6
        .i16(_forceRegionOffset + 8, 5) // speed_mps
        .i16(_forceRegionOffset + 10, 270) // course_deg
        .u8(_forceRegionOffset + 12, 8) // satellites
        .u8(_forceRegionOffset + 13, 1) // valid
        // ImuData in the angle region
        .f32(_angleRegionOffset, 0.5) // acc_x
        .f32(_angleRegionOffset + 4, -1.25) // acc_y
        .f32(_angleRegionOffset + 8, 9.81) // acc_z
        .build();
    // timestamp_ms at _angleRegionOffset + 12 left as 0.

    final packet = BluetoothPacket.decode(raw);

    expect(packet, isA<BoatPacket>());
    final boat = packet as BoatPacket;
    expect(boat.sensorId, 0);
    expect(boat.sequenceNumber, 42);
    expect(boat.gps.latitude, closeTo(47.123456, 1e-9));
    expect(boat.gps.longitude, closeTo(9.345678, 1e-9));
    expect(boat.gps.speedMps, 5);
    expect(boat.gps.courseDeg, 270);
    expect(boat.gps.satellites, 8);
    expect(boat.gps.valid, isTrue);
    expect(boat.imu.accX, closeTo(0.5, 1e-6));
    expect(boat.imu.accY, closeTo(-1.25, 1e-6));
    expect(boat.imu.accZ, closeTo(9.81, 1e-6));
    expect(boat.imu.timestampMs, 0);
  });
}
