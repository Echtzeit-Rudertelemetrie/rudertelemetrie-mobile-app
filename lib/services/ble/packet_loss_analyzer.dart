import 'dart:typed_data';

class PacketLossAnalyzer {
  int? _lastSeq;
  int _received = 0;
  int _lost = 0;
  int _outOfOrder = 0;
  int _duplicates = 0;
  final List<int> _gapSizes = [];

  void onPacket(List<int> raw) {
    if (raw.length < 84) {
      print('[PacketLoss] Unexpected packet size: ${raw.length} bytes (expected 84)');
      return;
    }

    final bytes = Uint8List.fromList(raw);
    final seq = ByteData.sublistView(bytes).getUint32(0, Endian.little);
    _received++;

    if (_lastSeq == null) {
      _lastSeq = seq;
      return;
    }

    final expected = _lastSeq! + 1;
    if (seq == expected) {
      // normal
    } else if (seq > expected) {
      final gap = seq - expected;
      _lost += gap;
      _gapSizes.add(gap);
    } else if (seq == _lastSeq) {
      _duplicates++;
    } else {
      _outOfOrder++;
    }

    _lastSeq = seq;
  }

  void printReport(Duration elapsed) {
    final total = _received + _lost;
    final lossPercent = total == 0 ? 0.0 : (_lost / total) * 100;
    final packetsPerSec = elapsed.inMilliseconds == 0
        ? 0.0
        : _received / (elapsed.inMilliseconds / 1000);

    print('');
    print('═══ BLE Packet Loss Report ═══');
    print('  Duration:     ${elapsed.inSeconds}s');
    print('  Received:     $_received');
    print('  Lost:         $_lost');
    print('  Loss rate:    ${lossPercent.toStringAsFixed(2)}%');
    print('  Out of order: $_outOfOrder');
    print('  Duplicates:   $_duplicates');
    print('  Packets/sec:  ${packetsPerSec.toStringAsFixed(1)}');
    if (_gapSizes.isNotEmpty) {
      _gapSizes.sort();
      print('  Gap sizes:    min=${_gapSizes.first}, max=${_gapSizes.last}, '
          'median=${_gapSizes[_gapSizes.length ~/ 2]}');
    }
    print('═══════════════════════════════');
    print('');
  }
}
