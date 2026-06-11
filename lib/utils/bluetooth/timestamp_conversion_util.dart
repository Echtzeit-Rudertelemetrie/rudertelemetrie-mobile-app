DateTime convertSequenceNumbersToTimestamp(DateTime start, int packetSequenceNumber, int dataSequenceNumber) {
  return start.add(
    Duration(milliseconds: packetSequenceNumber * 50 + dataSequenceNumber * 5),
  );
}
