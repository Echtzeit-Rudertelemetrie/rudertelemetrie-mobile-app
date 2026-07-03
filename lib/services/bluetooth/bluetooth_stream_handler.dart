import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/timestamp_conversion_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/sensor_data/angle_conversion_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/sensor_data/force_conversion_util.dart';

class BluetoothStreamHandler {
  final DataSourceRegistry dataSourceRegistry;

  final Map<String, PushDataSource> _dataSources = {};

  int? _boatDeviceClockOrigin;

  BluetoothStreamHandler({required this.dataSourceRegistry});

  void onPacket(List<int> raw) {
    final packet = BluetoothPacket.decode(raw);

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
    final force = _source('Force ${packet.sensorId}', Unit.N);
    final angle = _source('Angle ${packet.sensorId}', Unit.deg);

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
    final speed = _source('Speed', Unit.mps);
    final timestamp = _boatTimestamp(speed, packet.imu.timestampMs);

    speed.add(Measurement(
      value: packet.gps.speedMps.toDouble(),
      timestamp: timestamp,
    ));
    _source('Acceleration X', Unit.mps2)
        .add(Measurement(value: packet.imu.accX, timestamp: timestamp));
    _source('Acceleration Y', Unit.mps2)
        .add(Measurement(value: packet.imu.accY, timestamp: timestamp));
    _source('Acceleration Z', Unit.mps2)
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

  PushDataSource _source(String name, Unit unit) {
    return _dataSources.putIfAbsent(name, () {
      final source = PushDataSource(name: name, unit: unit);
      dataSourceRegistry.register(source);
      return source;
    });
  }

  void dispose() {
    for (final source in _dataSources.values) {
      dataSourceRegistry.unregister(source.name);
      source.dispose();
    }
    _dataSources.clear();
  }
}
