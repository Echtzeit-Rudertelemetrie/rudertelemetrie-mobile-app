import 'dart:typed_data';

/// Wire format sent by `rowing_boat` (firmware `MeasurementPack`, 132 bytes,
/// packed, little-endian):
///
///   [0..4)    idAndSeq : uint32   -> id = top 3 bits, sequence = low 29 bits
///   [4..68)   force region        -> 32 x uint16
///   [68..132) angle region        -> 32 x uint16
///
/// The id selects what the two regions mean:
///   id 0      -> boat telemetry: force region = GpsData, angle region = ImuData
///   id 1..7   -> oarlock #id:    force region = forces, angle region = angles
sealed class BluetoothPacket {
  static const packetSize = 132;

  static const _forceRegionOffset = 4;
  static const _angleRegionOffset = 68;
  static const _samplesPerRegion = 32;

  final int sensorId;
  final int sequenceNumber;

  BluetoothPacket({required this.sensorId, required this.sequenceNumber});

  static BluetoothPacket? decode(List<int> raw) {
    if (raw.length < packetSize) return null;

    final data = ByteData.sublistView(Uint8List.fromList(raw));
    final idAndSeq = data.getUint32(0, Endian.little);
    final sensorId = (idAndSeq >> 29) & 0x7;
    final sequenceNumber = idAndSeq & 0x1FFFFFFF;

    return sensorId == 0
        ? BoatPacket._decode(data, sequenceNumber)
        : OarlockPacket._decode(data, sensorId, sequenceNumber);
  }
}

class OarlockPacket extends BluetoothPacket {
  final List<int> forces;
  final List<int> angles;

  OarlockPacket._({
    required super.sensorId,
    required super.sequenceNumber,
    required this.forces,
    required this.angles,
  });

  static OarlockPacket _decode(ByteData data, int sensorId, int sequenceNumber) {
    return OarlockPacket._(
      sensorId: sensorId,
      sequenceNumber: sequenceNumber,
      forces: _readRegion(data, BluetoothPacket._forceRegionOffset),
      angles: _readRegion(data, BluetoothPacket._angleRegionOffset),
    );
  }

  static List<int> _readRegion(ByteData data, int offset) => [
        for (var i = 0; i < BluetoothPacket._samplesPerRegion; i++)
          data.getUint16(offset + i * 2, Endian.little),
      ];
}

class BoatPacket extends BluetoothPacket {
  final GpsSample gps;
  final ImuSample imu;

  BoatPacket._({
    required super.sensorId,
    required super.sequenceNumber,
    required this.gps,
    required this.imu,
  });

  static BoatPacket _decode(ByteData data, int sequenceNumber) {
    return BoatPacket._(
      sensorId: 0,
      sequenceNumber: sequenceNumber,
      gps: GpsSample._decode(data, BluetoothPacket._forceRegionOffset),
      imu: ImuSample._decode(data, BluetoothPacket._angleRegionOffset),
    );
  }
}

/// Firmware `GpsData` (14 bytes, packed) laid into the boat packet's force region.
class GpsSample {
  final double latitude;
  final double longitude;
  final int speedMps;
  final int courseDeg;
  final int satellites;
  final bool valid;

  GpsSample._({
    required this.latitude,
    required this.longitude,
    required this.speedMps,
    required this.courseDeg,
    required this.satellites,
    required this.valid,
  });

  static GpsSample _decode(ByteData data, int offset) {
    return GpsSample._(
      latitude: data.getInt32(offset, Endian.little) / 1e6,
      longitude: data.getInt32(offset + 4, Endian.little) / 1e6,
      speedMps: data.getInt16(offset + 8, Endian.little),
      courseDeg: data.getInt16(offset + 10, Endian.little),
      satellites: data.getUint8(offset + 12),
      valid: data.getUint8(offset + 13) != 0,
    );
  }
}

/// Firmware `ImuData` (16 bytes, packed) laid into the boat packet's angle region.
class ImuSample {
  final double accX;
  final double accY;
  final double accZ;
  final int timestampMs;

  ImuSample._({
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.timestampMs,
  });

  static ImuSample _decode(ByteData data, int offset) {
    return ImuSample._(
      accX: data.getFloat32(offset, Endian.little),
      accY: data.getFloat32(offset + 4, Endian.little),
      accZ: data.getFloat32(offset + 8, Endian.little),
      timestampMs: data.getUint32(offset + 12, Endian.little),
    );
  }
}
