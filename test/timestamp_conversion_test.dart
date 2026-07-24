import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/timestamp_conversion_util.dart';

void main() {
  test('timestamps remain monotonic across 32-sample packet boundaries', () {
    final start = DateTime(2026);
    final lastInPacket = convertSequenceNumbersToTimestamp(start, 0, 31);
    final firstInNextPacket = convertSequenceNumbersToTimestamp(start, 1, 0);

    expect(
      firstInNextPacket.difference(lastInPacket),
      const Duration(milliseconds: sensorSampleIntervalMs),
    );
  });
}
