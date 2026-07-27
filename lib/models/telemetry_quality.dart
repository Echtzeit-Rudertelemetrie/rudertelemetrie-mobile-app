import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';

enum TelemetryQualityLevel { waiting, live, delayed, interrupted }

@immutable
class TelemetryQuality {
  final TelemetryQualityLevel level;
  final int missingPackets;
  final int invalidPackets;
  final Duration? silence;

  const TelemetryQuality({
    required this.level,
    this.missingPackets = 0,
    this.invalidPackets = 0,
    this.silence,
  });

  static const waiting = TelemetryQuality(level: TelemetryQualityLevel.waiting);
}

class TelemetryQualityMonitor extends ChangeNotifier {
  static const _lagThreshold = Duration(milliseconds: 250);
  static const _interruptionThreshold = Duration(milliseconds: 600);
  static const _lossVisibleFor = Duration(seconds: 4);

  /// A spike is a burst of loss, not a stray packet. At one packet per
  /// [BluetoothPacket.samplesPerRegion] × [BluetoothPacket.sampleIntervalMs]
  /// (80 ms), losing this many inside [spikeWindow] is more than a second and a
  /// half of missing telemetry — worth interrupting the rower for. Anything
  /// less is noise the pipeline already absorbs.
  static const spikeWindow = Duration(seconds: 10);
  static const spikeThreshold = 20;

  /// Nothing here gets better by being told twice in a row.
  static const spikeCooldown = Duration(seconds: 30);

  final Map<String, _DeviceQuality> _devices = {};
  final Queue<_LossBurst> _recentLosses = Queue();
  late final Timer _timer;

  /// Raised with the number of packets lost in the trailing [spikeWindow].
  /// A callback rather than a stream so the monitor stays synchronous and free
  /// of any UI dependency.
  final void Function(int lostPackets)? onLossSpike;

  DateTime? _lastSpikeAt;

  TelemetryQualityMonitor({this.onLossSpike}) {
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => notifyListeners(),
    );
  }

  TelemetryQuality get quality => qualityAt(DateTime.now());

  TelemetryQuality qualityAt(DateTime now) {
    if (_devices.isEmpty) return TelemetryQuality.waiting;

    final latest = _devices.values
        .where((device) => device.lastPacketAt != null)
        .fold<DateTime?>(null, (current, device) {
          final timestamp = device.lastPacketAt!;
          return current == null || timestamp.isAfter(current)
              ? timestamp
              : current;
        });
    if (latest == null) {
      final invalid = _devices.values.fold(
        0,
        (sum, device) => sum + device.lastInvalid,
      );
      return invalid == 0
          ? TelemetryQuality.waiting
          : TelemetryQuality(
              level: TelemetryQualityLevel.delayed,
              invalidPackets: invalid,
            );
    }

    final silence = now.difference(latest);
    final recent = _devices.values.where(
      (device) =>
          device.lastProblemAt != null &&
          now.difference(device.lastProblemAt!) <= _lossVisibleFor,
    );
    final missing = recent.fold(0, (sum, device) => sum + device.lastMissing);
    final invalid = recent.fold(0, (sum, device) => sum + device.lastInvalid);

    return TelemetryQuality(
      level: _levelFor(silence, missing + invalid),
      missingPackets: missing,
      invalidPackets: invalid,
      silence: silence,
    );
  }

  void recordPacket(String deviceId, int sequenceNumber, {DateTime? now}) {
    final receivedAt = now ?? DateTime.now();
    final device = _devices.putIfAbsent(deviceId, _DeviceQuality.new);
    final previous = device.lastSequence;

    if (previous != null) {
      final advance =
          (sequenceNumber - previous) % BluetoothPacket.sequenceModulo;
      if (advance > 1 && advance < BluetoothPacket.sequenceModulo ~/ 2) {
        device.lastMissing = advance - 1;
        device.lastInvalid = 0;
        device.lastProblemAt = receivedAt;
        _recordLoss(advance - 1, receivedAt);
      }
    }

    device.lastSequence = sequenceNumber;
    device.lastPacketAt = receivedAt;
    notifyListeners();
  }

  void recordInvalidPacket(String deviceId, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final device = _devices.putIfAbsent(deviceId, _DeviceQuality.new);
    device.lastInvalid++;
    device.lastMissing = 0;
    device.lastProblemAt = at;
    _recordLoss(1, at);
    notifyListeners();
  }

  /// Folds one loss into the trailing window and reports a spike when the
  /// window's total crosses [spikeThreshold]. Losses are summed across devices:
  /// what the rower cares about is the boat's telemetry, not which oarlock.
  void _recordLoss(int packets, DateTime at) {
    _recentLosses.add(_LossBurst(at, packets));
    _dropLossesBefore(at.subtract(spikeWindow));

    final total = _recentLosses.fold(0, (sum, burst) => sum + burst.packets);
    if (total < spikeThreshold) return;

    final last = _lastSpikeAt;
    if (last != null && at.difference(last) < spikeCooldown) return;

    _lastSpikeAt = at;
    // Cleared so the next report needs a fresh burst rather than re-reporting
    // the same one the moment the cooldown lapses.
    _recentLosses.clear();
    onLossSpike?.call(total);
  }

  void _dropLossesBefore(DateTime cutoff) {
    while (_recentLosses.isNotEmpty &&
        _recentLosses.first.at.isBefore(cutoff)) {
      _recentLosses.removeFirst();
    }
  }

  void removeDevice(String deviceId) {
    if (_devices.remove(deviceId) != null) notifyListeners();
  }

  TelemetryQualityLevel _levelFor(Duration silence, int recentProblems) {
    if (silence >= _interruptionThreshold) {
      return TelemetryQualityLevel.interrupted;
    }
    if (silence >= _lagThreshold || recentProblems > 0) {
      return TelemetryQualityLevel.delayed;
    }
    return TelemetryQualityLevel.live;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

class _LossBurst {
  final DateTime at;
  final int packets;
  const _LossBurst(this.at, this.packets);
}

class _DeviceQuality {
  int? lastSequence;
  DateTime? lastPacketAt;
  DateTime? lastProblemAt;
  int lastMissing = 0;
  int lastInvalid = 0;
}
