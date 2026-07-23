import 'dart:async';

import 'package:flutter/foundation.dart';

/// Accumulates BLE throughput counters and prints a compact summary at a fixed
/// [interval] so the console stays readable instead of logging every packet.
///
/// Fragments and bytes are counted at the device level — they arrive before a
/// packet is decoded. Packets, values and loss are tracked per sensor id so
/// each oarlock and the telemetry stream can be read independently.
class PacketStatsLogger {
  final String label;
  final Duration interval;

  int _fragments = 0;
  int _bytes = 0;
  final Map<int, _StreamStats> _streams = {};
  Timer? _timer;

  PacketStatsLogger({
    required this.label,
    this.interval = const Duration(seconds: 3),
  });

  void recordFragment(int byteLength) {
    _fragments++;
    _bytes += byteLength;
    _timer ??= Timer.periodic(interval, (_) => _flush());
  }

  void recordPacket({
    required int sensorId,
    required int sequenceNumber,
    required int valueCount,
  }) {
    _streams
        .putIfAbsent(sensorId, _StreamStats.new)
        .record(sequenceNumber, valueCount);
  }

  void _flush() {
    if (_fragments == 0) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    final seconds = interval.inMilliseconds / 1000;
    debugPrint(_summary(seconds));
    _reset();
  }

  String _summary(double seconds) {
    final packets = _streams.values.fold(0, (sum, s) => sum + s.packets);
    final buffer = StringBuffer()
      ..write('[BLE $label] ')
      ..write('${(packets / seconds).toStringAsFixed(1)} pkt/s, ')
      ..write('${_perPacket(_bytes, packets).toStringAsFixed(0)} B/pkt, ')
      ..write('${_perPacket(_fragments, packets).toStringAsFixed(1)} frag/pkt ')
      ..write('over ${seconds.toStringAsFixed(0)}s '
          '($packets pkt, $_fragments frag, $_bytes B)');

    final ids = _streams.keys.toList()..sort();
    for (final id in ids) {
      final stream = _streams[id]!;
      if (stream.packets == 0) continue;
      buffer.write('\n  ${stream.summary(id, seconds)}');
    }
    return buffer.toString();
  }

  double _perPacket(int total, int packets) => packets == 0 ? 0 : total / packets;

  void _reset() {
    _fragments = 0;
    _bytes = 0;
    for (final stream in _streams.values) {
      stream.reset();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Per-sensor counters. [_lastSequence] survives [reset] so a gap straddling a
/// flush boundary is still counted.
class _StreamStats {
  int packets = 0;
  int values = 0;
  int lost = 0;
  int? _lastSequence;

  void record(int sequenceNumber, int valueCount) {
    packets++;
    values += valueCount;
    _countGap(sequenceNumber);
  }

  void _countGap(int sequenceNumber) {
    final last = _lastSequence;
    _lastSequence = sequenceNumber;
    if (last == null || sequenceNumber <= last) return;
    lost += sequenceNumber - last - 1;
  }

  String summary(int sensorId, double seconds) {
    final expected = packets + lost;
    final lossPercent = expected == 0 ? 0.0 : 100 * lost / expected;
    return 'id $sensorId: '
        '${(packets / seconds).toStringAsFixed(1)} pkt/s, '
        '${(values / seconds).toStringAsFixed(0)} val/s, '
        '$lost lost (${lossPercent.toStringAsFixed(1)}%)';
  }

  void reset() {
    packets = 0;
    values = 0;
    lost = 0;
  }
}
