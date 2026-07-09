/// Samples the firmware packs into a single `MeasurementPack` (`PACKET_VALUES`).
const _samplesPerPacket = 20;

/// Spacing between consecutive samples within the firmware's sample stream.
const _sampleIntervalMs = 5;

/// Maps a firmware packet sequence number and the sample's index within that
/// packet to an absolute timestamp. Each packet carries [_samplesPerPacket]
/// contiguous samples and the sequence number advances by one per packet, so
/// the global sample index is `packetSequenceNumber * samplesPerPacket + index`.
DateTime convertSequenceNumbersToTimestamp(
  DateTime start,
  int packetSequenceNumber,
  int dataSequenceNumber,
) {
  final sampleIndex =
      packetSequenceNumber * _samplesPerPacket + dataSequenceNumber;
  return start.add(Duration(milliseconds: sampleIndex * _sampleIntervalMs));
}
