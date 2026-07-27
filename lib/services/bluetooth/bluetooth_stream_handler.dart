import 'dart:async';
import 'dart:collection';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/models/speed_settings_model.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/speed_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/bluetooth/gps_packet_log.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibrations.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/packet_reassembler.dart';
import 'package:rudertelemetrie_mobile_app/utils/sensor_data/angle_conversion_util.dart';

class BluetoothStreamHandler {
  final DataSourceRegistry dataSourceRegistry;
  final String deviceId;
  final SpeedSettingsModel speedSettings;
  final void Function(int sequenceNumber)? onOarlockPacket;
  final void Function()? onInvalidPacket;

  /// Optional so a headless or test handler can stream without config; without
  /// it every oarlock reads on the nominal firmware scale.
  final ForceCalibrations? calibrations;

  final Map<String, DataSource> _dataSources = {};
  final Map<int, _OarlockStream> _oarlocks = {};

  int? _boatDeviceClockOrigin;
  double? _boatRotationDeg;

  late final PacketReassembler _reassembler = PacketReassembler(_decodeFrame);
  late final GpsPacketLog _gpsLog = GpsPacketLog(deviceId: _deviceTag);

  BluetoothStreamHandler({
    required this.dataSourceRegistry,
    required this.deviceId,
    required this.speedSettings,
    this.onOarlockPacket,
    this.onInvalidPacket,
    this.calibrations,
  });

  void onData(List<int> value) {
    if (value.length != BluetoothPacket.packetSize) {
      onInvalidPacket?.call();
      return;
    }
    _reassembler.addFragment(value);
  }

  void _decodeFrame(List<int> frame) {
    final packet = BluetoothPacket.decode(frame);

    switch (packet) {
      case null:
        return;
      case OarlockPacket():
        _handleOarlock(packet);
      case BoatPacket():
        _handleBoat(packet, frame);
    }
  }

  void _handleOarlock(OarlockPacket packet) {
    final stream = _oarlockStream(packet.sensorId);
    final advance = stream.acceptSequence(packet.sequenceNumber);
    if (advance == null) return; // duplicate or late retry

    onOarlockPacket?.call(packet.sequenceNumber);
    stream.enqueue(packet, advance);
  }

  _OarlockStream _oarlockStream(int sensorId) {
    return _oarlocks.putIfAbsent(sensorId, () {
      final group = 'Oarlock $sensorId ($_deviceTag)';
      return _OarlockStream(
        oarlockKey: group,
        calibrations: calibrations,
        force: _source('Force $sensorId', Unit.N, group: group),
        angle: _source('Angle $sensorId', Unit.deg, group: group),
        rawAngle: _source('Raw Angle $sensorId', Unit.deg, group: group),
        boatRotationDeg: () => _boatRotationDeg,
      );
    });
  }

  void _handleBoat(BoatPacket packet, List<int> frame) {
    _gpsLog.record(packet, DateTime.now(), rawFrame: frame);
    final group = 'Boat ($_deviceTag)';
    final speed = _speedSource(group);
    final timestamp = _boatTimestamp(speed, packet.imu.timestampMs);
    // The installed boat IMU was physically verified on 2026-07-27: a flat
    // 42-degree turn changed pitch by 42 degrees while yaw/roll stayed near 0.
    _boatRotationDeg = packet.imu.pitchDeg;

    if (packet.gps.valid) {
      speed.addMps(
        Measurement(value: packet.gps.speedMps, timestamp: timestamp),
      );
      _source(
        'Latitude',
        Unit.deg,
        group: group,
      ).add(Measurement(value: packet.gps.latitude, timestamp: timestamp));
      _source(
        'Longitude',
        Unit.deg,
        group: group,
      ).add(Measurement(value: packet.gps.longitude, timestamp: timestamp));
    }
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
    _source(
      'Boat Roll',
      Unit.deg,
      group: group,
    ).add(Measurement(value: packet.imu.rollDeg, timestamp: timestamp));
    _source(
      'Boat Pitch',
      Unit.deg,
      group: group,
    ).add(Measurement(value: packet.imu.pitchDeg, timestamp: timestamp));
    _source(
      'Boat Yaw',
      Unit.deg,
      group: group,
    ).add(Measurement(value: packet.imu.yawDeg, timestamp: timestamp));
  }

  DateTime _boatTimestamp(DataSource source, int deviceMs) {
    final origin = _boatDeviceClockOrigin ??= deviceMs;
    return source.startTime.add(Duration(milliseconds: deviceMs - origin));
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
        })
        as PushDataSource;
  }

  SpeedDataSource _speedSource(String group) {
    return _dataSources.putIfAbsent('Speed', () {
          final source = SpeedDataSource(
            name: _qualify('Speed'),
            settings: speedSettings,
            group: group,
          );
          dataSourceRegistry.register(source);
          return source;
        })
        as SpeedDataSource;
  }

  String _qualify(String name) => '$name ($_deviceTag)';

  String get _deviceTag {
    final compact = deviceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return compact.length <= 4
        ? compact
        : compact.substring(compact.length - 4);
  }

  void dispose() {
    for (final stream in _oarlocks.values) {
      stream.dispose();
    }
    _oarlocks.clear();
    for (final source in _dataSources.values) {
      dataSourceRegistry.unregister(source.name);
      source.dispose();
    }
    _dataSources.clear();
  }
}

/// One oarlock's force/angle pair, with its packets released at the sensor's own
/// sample rate.
///
/// A BLE notification delivers a whole packet at once. Pushing all of it into
/// the chart in a single frame makes the trace advance in visible steps, so the
/// samples are buffered and paid out against a wall clock instead. Timestamps
/// are anchored to the source's start time rather than to the firmware's
/// sequence counter, which is already running when the app connects.
class _OarlockStream {
  static const _tickInterval = Duration(milliseconds: 16);
  static const _packetDuration = Duration(
    milliseconds:
        BluetoothPacket.samplesPerRegion * BluetoothPacket.sampleIntervalMs,
  );

  /// Sequence gap treated as a late retry rather than a sender restart.
  static const _maxLatePackets = 64;

  final String oarlockKey;
  final ForceCalibrations? calibrations;
  final PushDataSource force;
  final PushDataSource angle;
  final PushDataSource rawAngle;
  final double? Function() boatRotationDeg;

  final Queue<_OarlockSample> _pending = Queue();
  final Stopwatch _clock = Stopwatch();

  int? _lastSequence;
  DateTime? _nextTimestamp;
  int _emitted = 0;
  Timer? _timer;

  _OarlockStream({
    required this.oarlockKey,
    required this.calibrations,
    required this.force,
    required this.angle,
    required this.rawAngle,
    required this.boatRotationDeg,
  });

  /// Returns the forward sequence advance, 1 after a sender restart, or null
  /// for a duplicate / slightly late retry. This keeps timestamps monotonic
  /// even when the embedded sender reboots and starts its sequence at zero.
  int? acceptSequence(int sequence) {
    const modulo = BluetoothPacket.sequenceModulo;
    final previous = _lastSequence;
    if (previous == null) {
      _lastSequence = sequence;
      return 1;
    }

    final advance = (sequence - previous) % modulo;
    if (advance == 0) return null;
    if (advance < modulo ~/ 2) {
      _lastSequence = sequence;
      return advance;
    }

    if ((previous - sequence) % modulo <= _maxLatePackets) return null;

    // Large backwards jump: sender restarted. Continue directly after the
    // previous local sample instead of jumping the chart back to t=0.
    _lastSequence = sequence;
    _pending.clear();
    return 1;
  }

  void enqueue(OarlockPacket packet, int advance) {
    if (_timer != null) _emitDue();
    // A backlog longer than one packet means playback has fallen behind the
    // sender; showing stale samples is worse than skipping them.
    if (_pending.length > BluetoothPacket.samplesPerRegion) _pending.clear();

    final start = _packetStart(advance);
    for (var i = 0; i < packet.forces.length; i++) {
      final timestamp = start.add(
        Duration(milliseconds: i * BluetoothPacket.sampleIntervalMs),
      );
      _pending.add(
        _OarlockSample(
          force: Measurement(
            value: _newtons(packet.forces[i], timestamp),
            timestamp: timestamp,
          ),
          angle: Measurement(
            value: convertAngleSensorData(packet.angles[i]),
            timestamp: timestamp,
          ),
        ),
      );
    }
    _nextTimestamp = start.add(_packetDuration);
    _start();
  }

  /// Calibration is applied here rather than downstream so that `Force N` stays
  /// the one force source per oarlock — saved dashboards bind to it by name.
  double _newtons(int raw, DateTime timestamp) =>
      calibrations?.newtons(oarlockKey, raw, timestamp) ??
      ForceCalibration.uncalibrated.newtons(raw);

  /// Leaves a gap for packets lost in transit, so a dropped packet shows as a
  /// gap in the trace rather than compressing time.
  DateTime _packetStart(int advance) {
    final start = _nextTimestamp ?? force.startTime;
    return advance > 1 ? start.add(_packetDuration * (advance - 1)) : start;
  }

  void _start() {
    if (_timer != null) return;
    _emitted = 0;
    _clock
      ..reset()
      ..start();
    _timer = Timer.periodic(_tickInterval, (_) => _emitDue());
  }

  void _emitDue() {
    if (_pending.isEmpty) {
      _stop();
      return;
    }

    final target =
        _clock.elapsedMilliseconds ~/ BluetoothPacket.sampleIntervalMs;
    final due = target - _emitted;
    _emitted = target;

    for (var i = 0; i < due && _pending.isNotEmpty; i++) {
      final sample = _pending.removeFirst();
      force.add(sample.force);
      rawAngle.add(sample.angle);
      final boatRotation = boatRotationDeg();
      angle.add(
        Measurement(
          value: boatRotation == null
              ? sample.angle.value
              // The two installed IMUs use opposite signs for the same
              // physical boat turn, so adding pitch cancels common rotation.
              : _wrapDegrees(sample.angle.value + boatRotation),
          timestamp: sample.angle.timestamp,
        ),
      );
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
  }

  void dispose() {
    _stop();
    _pending.clear();
  }
}

double _wrapDegrees(double angle) {
  while (angle > 180) {
    angle -= 360;
  }
  while (angle <= -180) {
    angle += 360;
  }
  return angle;
}

class _OarlockSample {
  final Measurement force;
  final Measurement angle;

  const _OarlockSample({required this.force, required this.angle});
}
