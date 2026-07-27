import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';

/// Byte-exact fixtures mirroring the firmware `MeasurementPack` (36 bytes,
/// packed, little-endian) as emitted by `rowing_boat`.
class _PackBuilder {
  final ByteData _data = ByteData(BluetoothPacket.packetSize);

  _PackBuilder(int id, int sequence) {
    _data.setUint32(
      0,
      ((id & 0xF) << 28) | (sequence & 0x0FFFFFFF),
      Endian.little,
    );
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

  List<int> build() => _data.buffer.asUint8List();
}

void main() {
  test('returns null for undersized buffers', () {
    expect(
      BluetoothPacket.decode(List.filled(BluetoothPacket.packetSize - 1, 0)),
      isNull,
    );
  });

  test('splits id (top 4 bits) and 28-bit sequence from the header', () {
    final raw = _PackBuilder(13, 0x0ABCDEF).build();
    final packet = BluetoothPacket.decode(raw)!;

    expect(packet.sensorId, 13);
    expect(packet.sequenceNumber, 0x0ABCDEF);
  });

  test('decodes an oarlock packet (id 1..15) into force and angle samples', () {
    final builder = _PackBuilder(2, 7);
    for (var i = 0; i < BluetoothPacket.samplesPerRegion; i++) {
      builder.u16(4 + i * 2, 100 + i); // force region
      builder.u16(
        4 + BluetoothPacket.samplesPerRegion * 2 + i * 2,
        500 + i,
      ); // angle region
    }

    final packet = BluetoothPacket.decode(builder.build());

    expect(packet, isA<OarlockPacket>());
    final oarlock = packet as OarlockPacket;
    expect(oarlock.sensorId, 2);
    expect(oarlock.forces.length, 8);
    expect(oarlock.angles.length, 8);
    expect(oarlock.forces.first, 100);
    expect(oarlock.forces.last, 107);
    expect(oarlock.angles.first, 500);
    expect(oarlock.angles.last, 507);
  });

  test('decodes a boat packet (id 0) into GPS and IMU samples', () {
    final raw = _PackBuilder(0, 42)
        // GpsData in the force region (offset 4)
        .i32(4, 47123456) // lat * 1e6
        .i32(8, 9345678) // lon * 1e6
        .u16(12, 523) // speed_cms = 5.23 m/s
        .u16(14, 27025) // course_cdeg = 270.25°
        .u8(16, 8) // satellites
        .u8(17, 1) // valid
        // ImuData in the angle region (offset 20)
        .i16(20, 51) // acc_x = 51 mg
        .i16(22, -127) // acc_y = -127 mg
        .i16(24, 1000) // acc_z = 1 g
        .i16(26, 1250) // roll = 12.50°
        .i16(28, -325) // pitch = -3.25°
        .i16(30, 9075) // yaw = 90.75°
        .build();
    // timestamp_ms at offset 32 left as 0.

    final packet = BluetoothPacket.decode(raw);

    expect(packet, isA<BoatPacket>());
    final boat = packet as BoatPacket;
    expect(boat.sensorId, 0);
    expect(boat.sequenceNumber, 42);
    expect(boat.gps.latitude, closeTo(47.123456, 1e-9));
    expect(boat.gps.longitude, closeTo(9.345678, 1e-9));
    expect(boat.gps.speedMps, 5.23);
    expect(boat.gps.courseDeg, 270.25);
    expect(boat.gps.satellites, 8);
    expect(boat.gps.valid, isTrue);
    expect(boat.imu.accX, closeTo(0.500139, 1e-6));
    expect(boat.imu.accY, closeTo(-1.245445, 1e-6));
    expect(boat.imu.accZ, closeTo(9.80665, 1e-6));
    expect(boat.imu.rollDeg, 12.5);
    expect(boat.imu.pitchDeg, -3.25);
    expect(boat.imu.yawDeg, 90.75);
    expect(boat.imu.timestampMs, 0);
  });
}
