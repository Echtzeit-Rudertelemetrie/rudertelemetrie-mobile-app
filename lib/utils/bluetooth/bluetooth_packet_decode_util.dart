class BluetoothPacket {
  final int sequenceNumber;
  final List<BluetoothPacketData> data;

  BluetoothPacket({required this.sequenceNumber, required this.data});
}

class BluetoothPacketData {
  final int force;
  final int angle;
  final int id;
  final int sequenceNumber;

  BluetoothPacketData({
    required this.force,
    required this.angle,
    required this.id,
    required this.sequenceNumber,
  });
}

BluetoothPacket? decodeBluetoothPacket(List<int> raw) {
  if (raw.length < 4) return null;

  int offset = 0;

  int readU16LE() {
    final v = raw[offset] | (raw[offset + 1] << 8);
    offset += 2;
    return v;
  }

  int readU32LE() {
    final v = raw[offset] |
    (raw[offset + 1] << 8) |
    (raw[offset + 2] << 16) |
    (raw[offset + 3] << 24);
    offset += 4;
    return v;
  }

  if (raw.length < 4 + 20 * 5) return null;

  final packetSeq = readU32LE();

  final data = <BluetoothPacketData>[];
  final idCounters = <int, int>{};

  for (int i = 0; i < 20; i++) {
    if (offset + 5 > raw.length) return null;

    final force = readU16LE();
    final angle = readU16LE();

    final id = raw[offset] & 0x07;
    offset += 1;

    final seqForId = idCounters[id] ?? 0;
    idCounters[id] = seqForId + 1;

    data.add(
      BluetoothPacketData(
        force: force,
        angle: angle,
        id: id,
        sequenceNumber: seqForId,
      ),
    );
  }

  return BluetoothPacket(
    sequenceNumber: packetSeq,
    data: data,
  );
}
