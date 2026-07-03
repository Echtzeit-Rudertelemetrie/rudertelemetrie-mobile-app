import 'dart:math';
import 'dart:typed_data';

class BitReader {
  final Uint8List _bytes;
  int _bitOffset = 0;

  BitReader(List<int> bytes) : _bytes = Uint8List.fromList(bytes);

  int get remainingBits => (_bytes.length * 8) - _bitOffset;

  int read(int bitCount) {
    int value = 0;
    int bitsRead = 0;

    while (bitsRead < bitCount) {
      final byteIndex = _bitOffset ~/ 8;
      final bitIndex = _bitOffset % 8;
      final bitsAvailable = 8 - bitIndex;
      final bitsToRead = min(bitCount - bitsRead, bitsAvailable);

      final mask = (1 << bitsToRead) - 1;
      value |= ((_bytes[byteIndex] >> bitIndex) & mask) << bitsRead;

      _bitOffset += bitsToRead;
      bitsRead += bitsToRead;
    }

    return value;
  }

  void skip(int bitCount) {
    _bitOffset += bitCount;
  }
}

sealed class SensorReading {
  static const bitSize = 40;

  final int sensorId;

  SensorReading({required this.sensorId});

  static SensorReading decode(BitReader reader) {
    final sensorId = reader.read(4);
    reader.skip(4);

    return switch (sensorId) {
      0 => BoatReading._decode(reader, sensorId: sensorId),
      _ => OarlockReading._decode(reader, sensorId: sensorId),
    };
  }
}

class OarlockReading extends SensorReading {
  final int force;
  final int angle;

  OarlockReading._({
    required super.sensorId,
    required this.force,
    required this.angle,
  });

  static OarlockReading _decode(BitReader reader, {required int sensorId}) {
    final force = reader.read(16);
    final angle = reader.read(16);

    return OarlockReading._(sensorId: sensorId, force: force, angle: angle);
  }
}

class BoatReading extends SensorReading {
  final int payload;

  BoatReading._({required super.sensorId, required this.payload});

  static BoatReading _decode(BitReader reader, {required int sensorId}) {
    return BoatReading._(sensorId: sensorId, payload: reader.read(32));
  }
}

class BluetoothPacket {
  static const _headerBits = 32;
  static const _readingsPerPacket = 20;
  static const packetSize =
      (_headerBits + _readingsPerPacket * SensorReading.bitSize) ~/ 8;

  final int sequenceNumber;
  final List<SensorReading> readings;

  BluetoothPacket._({required this.sequenceNumber, required this.readings});

  static BluetoothPacket? decode(List<int> raw) {
    if (raw.length < packetSize) return null;

    final reader = BitReader(raw);

    return BluetoothPacket._(
      sequenceNumber: reader.read(32),
      readings: [
        for (var i = 0; i < _readingsPerPacket; i++)
          SensorReading.decode(reader),
      ],
    );
  }
}
