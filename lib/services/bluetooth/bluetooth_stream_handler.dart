import 'dart:async';
import 'dart:collection';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/packet_reassembler.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/timestamp_conversion_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/sensor_data/angle_conversion_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/sensor_data/force_conversion_util.dart';

class BluetoothStreamHandler {
  final DataSourceRegistry dataSourceRegistry;
  final String deviceId;
  final void Function(int sequenceNumber)? onOarlockPacket;
  final void Function()? onInvalidPacket;

  final Map<String, PushDataSource> _dataSources = {};
  final Queue<_OarlockSample> _pendingOarlockSamples = Queue();
  final Stopwatch _playbackClock = Stopwatch();

  int? _boatDeviceClockOrigin;
  int? _lastOarlockSequence;
  DateTime? _nextOarlockTimestamp;
  int _playbackSamples = 0;
  Timer? _sampleTimer;

  late final PacketReassembler _reassembler = PacketReassembler(_decodeFrame);

  BluetoothStreamHandler({
    required this.dataSourceRegistry,
    required this.deviceId,
    this.onOarlockPacket,
    this.onInvalidPacket,
  });

  void onData(List<int> fragment) {
    if (fragment.length != BluetoothPacket.packetSize) {
      onInvalidPacket?.call();
      return;
    }
    _reassembler.addFragment(fragment);
  }

  void _decodeFrame(List<int> frame) {
    final packet = BluetoothPacket.decode(frame);

    switch (packet) {
      case null:
        return;
      case OarlockPacket():
        _handleOarlock(packet);
      case BoatPacket():
        _handleBoat(packet);
    }
  }

  void _handleOarlock(OarlockPacket packet) {
    final sequenceAdvance = _acceptOarlockSequence(packet.sequenceNumber);
    if (sequenceAdvance == null) return; // duplicate or late retry

    onOarlockPacket?.call(packet.sequenceNumber);
    // The current production setup has one oarlock per BLE hub. Keep the wire
    // protocol ID internal instead of exposing misleading Force/Angle 1..15
    // sources in the dashboard.
    final group = 'Oarlock ($_deviceTag)';
    final force = _source('Force', Unit.N, group: group);
    final angle = _source('Angle', Unit.deg, group: group);

    if (_sampleTimer != null) _emitDueOarlockSamples(force, angle);
    if (_pendingOarlockSamples.length > BluetoothPacket.samplesPerRegion) {
      _pendingOarlockSamples.clear();
    }

    var packetStart = _nextOarlockTimestamp ?? force.startTime;
    if (sequenceAdvance > 1) {
      packetStart = packetStart.add(
        Duration(
          milliseconds:
              (sequenceAdvance - 1) *
              BluetoothPacket.samplesPerRegion *
              sensorSampleIntervalMs,
        ),
      );
    }

    for (var i = 0; i < packet.forces.length; i++) {
      final timestamp = packetStart.add(
        Duration(milliseconds: i * sensorSampleIntervalMs),
      );
      _pendingOarlockSamples.add(
        _OarlockSample(
          force: Measurement(
            value: convertForceSensorData(packet.forces[i]),
            timestamp: timestamp,
          ),
          angle: Measurement(
            value: convertAngleSensorData(packet.angles[i]),
            timestamp: timestamp,
          ),
        ),
      );
    }
    _nextOarlockTimestamp = packetStart.add(
      const Duration(
        milliseconds: BluetoothPacket.samplesPerRegion * sensorSampleIntervalMs,
      ),
    );

    _startSampleTimer(force, angle);
  }

  void _startSampleTimer(PushDataSource force, PushDataSource angle) {
    if (_sampleTimer != null) return;
    _playbackSamples = 0;
    _playbackClock
      ..reset()
      ..start();
    _sampleTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _emitDueOarlockSamples(force, angle),
    );
  }

  void _emitDueOarlockSamples(PushDataSource force, PushDataSource angle) {
    if (_pendingOarlockSamples.isEmpty) {
      _stopSampleTimer();
      return;
    }

    final targetSamples =
        _playbackClock.elapsedMilliseconds ~/ sensorSampleIntervalMs;
    final dueSamples = targetSamples - _playbackSamples;
    _playbackSamples = targetSamples;

    for (var i = 0; i < dueSamples && _pendingOarlockSamples.isNotEmpty; i++) {
      final sample = _pendingOarlockSamples.removeFirst();
      force.add(sample.force);
      angle.add(sample.angle);
    }
  }

  void _stopSampleTimer() {
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _playbackClock.stop();
  }

  void _handleBoat(BoatPacket packet) {
    final group = 'Boat ($_deviceTag)';
    final speed = _source('Speed', Unit.mps, group: group);
    final timestamp = _boatTimestamp(speed, packet.imu.timestampMs);

    speed.add(
      Measurement(value: packet.gps.speedMps.toDouble(), timestamp: timestamp),
    );
    _source(
      'Acceleration X',
      Unit.mps2,
      group: group,
    ).add(Measurement(value: packet.imu.accX, timestamp: timestamp));
    _source(
      'Acceleration Y',
      Unit.mps2,
      group: group,
    ).add(Measurement(value: packet.imu.accY, timestamp: timestamp));
    _source(
      'Acceleration Z',
      Unit.mps2,
      group: group,
    ).add(Measurement(value: packet.imu.accZ, timestamp: timestamp));
  }

  DateTime _boatTimestamp(PushDataSource source, int deviceMs) {
    final origin = _boatDeviceClockOrigin ??= deviceMs;
    return source.startTime.add(Duration(milliseconds: deviceMs - origin));
  }

  /// Returns the forward sequence advance, 1 after a sender restart, or null
  /// for a duplicate / slightly late retry. This keeps timestamps monotonic
  /// even when the embedded sender reboots and starts its sequence at zero.
  int? _acceptOarlockSequence(int sequence) {
    const modulo = 1 << 28;
    const halfModulo = modulo ~/ 2;
    const maxLatePackets = 64;
    final previous = _lastOarlockSequence;
    if (previous == null) {
      _lastOarlockSequence = sequence;
      return 1;
    }

    final advance = (sequence - previous) % modulo;
    if (advance == 0) return null;
    if (advance < halfModulo) {
      _lastOarlockSequence = sequence;
      return advance;
    }

    final backwards = (previous - sequence) % modulo;
    if (backwards <= maxLatePackets) return null;

    // Large backwards jump: sender restarted. Continue directly after the
    // previous local sample instead of jumping the chart back to t=0.
    _lastOarlockSequence = sequence;
    _pendingOarlockSamples.clear();
    return 1;
  }

  PushDataSource _source(String name, Unit unit, {String? group}) {
    return _dataSources.putIfAbsent(name, () {
      final source = PushDataSource(
        name: _qualify(name),
        unit: unit,
        group: group,
      );
      dataSourceRegistry.register(source);
      return source;
    });
  }

  String _qualify(String name) => '$name ($_deviceTag)';

  String get _deviceTag {
    final compact = deviceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return compact.length <= 4
        ? compact
        : compact.substring(compact.length - 4);
  }

  void dispose() {
    _stopSampleTimer();
    _pendingOarlockSamples.clear();
    for (final source in _dataSources.values) {
      dataSourceRegistry.unregister(source.name);
      source.dispose();
    }
    _dataSources.clear();
  }
}

class _OarlockSample {
  final Measurement force;
  final Measurement angle;

  const _OarlockSample({required this.force, required this.angle});
}
