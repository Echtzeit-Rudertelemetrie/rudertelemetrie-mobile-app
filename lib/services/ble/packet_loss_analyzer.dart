import 'dart:typed_data';

class PacketLossAnalyzer {
  int? _lastSeq;
  int _received = 0;
  int _lost = 0;
  int _outOfOrder = 0;
  int _duplicates = 0;
  final List<int> _gapSizes = [];

  DateTime? _firstReceiveTime;
  int? _firstEspTimestamp;
  final List<double> _delays = [];

  void onPacket(List<int> raw) {
    if (raw.length < 88) {
      print('[PacketLoss] Unexpected packet size: ${raw.length} bytes (expected 88)');
      return;
    }

    final now = DateTime.now();
    final bytes = Uint8List.fromList(raw);
    final data = ByteData.sublistView(bytes);
    final seq = data.getUint32(0, Endian.little);
    final espTimestamp = data.getUint32(4, Endian.little);

    _received++;

    _firstReceiveTime ??= now;
    _firstEspTimestamp ??= espTimestamp;

    final espElapsed = espTimestamp - _firstEspTimestamp!;
    final phoneElapsed = now.difference(_firstReceiveTime!).inMilliseconds;
    _delays.add((phoneElapsed - espElapsed).toDouble());

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
    print('');
    _printDelayReport();
    print('═══════════════════════════════');
    print('');
  }

  void _printDelayReport() {
    if (_delays.isEmpty) return;

    _delays.sort();
    final min = _delays.first;
    final max = _delays.last;
    final median = _delays[_delays.length ~/ 2];
    final mean = _delays.reduce((a, b) => a + b) / _delays.length;
    final p95 = _delays[(_delays.length * 0.95).floor()];
    final p99 = _delays[(_delays.length * 0.99).floor()];
    final jitter = max - min;

    print('── Delay Analysis (relative) ──');
    print('  Min:          ${min.toStringAsFixed(1)} ms');
    print('  Max:          ${max.toStringAsFixed(1)} ms');
    print('  Mean:         ${mean.toStringAsFixed(1)} ms');
    print('  Median:       ${median.toStringAsFixed(1)} ms');
    print('  P95:          ${p95.toStringAsFixed(1)} ms');
    print('  P99:          ${p99.toStringAsFixed(1)} ms');
    print('  Jitter:       ${jitter.toStringAsFixed(1)} ms');
  }
}
