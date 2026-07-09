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

  final Map<String, PushDataSource> _dataSources = {};

  int? _boatDeviceClockOrigin;

  late final PacketReassembler _reassembler = PacketReassembler(_decodeFrame);

  BluetoothStreamHandler({
    required this.dataSourceRegistry,
    required this.deviceId,
  });

  void onData(List<int> fragment) => _reassembler.addFragment(fragment);

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
    final group = 'Oarlock ${packet.sensorId} ($_deviceTag)';
    final force = _source('Force ${packet.sensorId}', Unit.N, group: group);
    final angle = _source('Angle ${packet.sensorId}', Unit.deg, group: group);

    for (var i = 0; i < packet.forces.length; i++) {
      final timestamp = _timestampFor(force, packet.sequenceNumber, i);

      force.add(Measurement(
        value: convertForceSensorData(packet.forces[i]),
        timestamp: timestamp,
      ));
      angle.add(Measurement(
        value: convertAngleSensorData(packet.angles[i]),
        timestamp: timestamp,
      ));
    }
  }

  void _handleBoat(BoatPacket packet) {
    final group = 'Boat ($_deviceTag)';
    final speed = _source('Speed', Unit.mps, group: group);
    final timestamp = _boatTimestamp(speed, packet.imu.timestampMs);

    speed.add(Measurement(
      value: packet.gps.speedMps.toDouble(),
      timestamp: timestamp,
    ));
    _source('Acceleration X', Unit.mps2, group: group)
        .add(Measurement(value: packet.imu.accX, timestamp: timestamp));
    _source('Acceleration Y', Unit.mps2, group: group)
        .add(Measurement(value: packet.imu.accY, timestamp: timestamp));
    _source('Acceleration Z', Unit.mps2, group: group)
        .add(Measurement(value: packet.imu.accZ, timestamp: timestamp));
  }

  DateTime _boatTimestamp(PushDataSource source, int deviceMs) {
    final origin = _boatDeviceClockOrigin ??= deviceMs;
    return source.startTime.add(Duration(milliseconds: deviceMs - origin));
  }

  DateTime _timestampFor(PushDataSource source, int packetSequenceNumber, int index) {
    return convertSequenceNumbersToTimestamp(
      source.startTime,
      packetSequenceNumber,
      index,
    );
  }

  PushDataSource _source(String name, Unit unit, {String? group}) {
    return _dataSources.putIfAbsent(name, () {
      final source =
          PushDataSource(name: _qualify(name), unit: unit, group: group);
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
    for (final source in _dataSources.values) {
      dataSourceRegistry.unregister(source.name);
      source.dispose();
    }
    _dataSources.clear();
  }
}
