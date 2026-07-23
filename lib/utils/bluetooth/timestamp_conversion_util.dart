import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';

/// Spacing between consecutive samples within the firmware's sample stream.
/// The sensor node samples at 100 Hz (10 ms), capped by the ICM-20948
/// magnetometer — see rowing_boat EspNow_sender_App (`timer_.begin(100)`).
const _sampleIntervalMs = 10;

/// Maps a firmware packet sequence number and the sample's index within that
/// packet to an absolute timestamp. Each packet carries
/// [BluetoothPacket.samplesPerPacket] contiguous samples and the sequence number
/// advances by one per packet, so the global sample index is
/// `packetSequenceNumber * samplesPerPacket + index`.
DateTime convertSequenceNumbersToTimestamp(
  DateTime start,
  int packetSequenceNumber,
  int dataSequenceNumber,
) {
  final sampleIndex = packetSequenceNumber * BluetoothPacket.samplesPerPacket +
      dataSequenceNumber;
  return start.add(Duration(milliseconds: sampleIndex * _sampleIntervalMs));
}
