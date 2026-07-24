import 'dart:async';

import 'package:flutter/foundation.dart';

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
  static const _sequenceModulo = 1 << 28;
  static const _lagThreshold = Duration(milliseconds: 250);
  static const _interruptionThreshold = Duration(milliseconds: 600);
  static const _lossVisibleFor = Duration(seconds: 4);

  final Map<String, _DeviceQuality> _devices = {};
  late final Timer _timer;

  TelemetryQualityMonitor() {
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
      final advance = (sequenceNumber - previous) % _sequenceModulo;
      if (advance > 1 && advance < _sequenceModulo ~/ 2) {
        device.lastMissing = advance - 1;
        device.lastInvalid = 0;
        device.lastProblemAt = receivedAt;
      }
    }

    device.lastSequence = sequenceNumber;
    device.lastPacketAt = receivedAt;
    notifyListeners();
  }

  void recordInvalidPacket(String deviceId, {DateTime? now}) {
    final device = _devices.putIfAbsent(deviceId, _DeviceQuality.new);
    device.lastInvalid++;
    device.lastMissing = 0;
    device.lastProblemAt = now ?? DateTime.now();
    notifyListeners();
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

class _DeviceQuality {
  int? lastSequence;
  DateTime? lastPacketAt;
  DateTime? lastProblemAt;
  int lastMissing = 0;
  int lastInvalid = 0;
}
