import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/force_data_source.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/bluetooth_packet_decode_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/bluetooth/timestamp_conversion_util.dart';
import 'package:rudertelemetrie_mobile_app/utils/sensor_data/force_conversion_util.dart';

class BluetoothStreamHandler {
  final DataSourceRegistry dataSourceRegistry;

  final Map<String, ForceDataSource> _forceDataSources = {};

  BluetoothStreamHandler({ required this.dataSourceRegistry });

  void onPacket(List<int> raw) {
    final packet = decodeBluetoothPacket(raw);

    if (packet == null) return;

    for (var data in packet.data) {
      _emitValues(packet.sequenceNumber, data);
    }
  }

  void _emitValues(int packetSequenceNumber, BluetoothPacketData packetData) {
    final BluetoothPacketData(:force, :angle, :id) = packetData;

    final dataSource = _ensureForceDataSourceExists(id);

    final value = convertForceSensorData(force);
    final timestamp = convertSequenceNumbersToTimestamp(
        dataSource.startTime,
        packetSequenceNumber,
        packetData.sequenceNumber
    );

    final measurementForce = Measurement(value: value, timestamp: timestamp);

    dataSource.add(measurementForce);
  }

  ForceDataSource _ensureForceDataSourceExists(int id) {
    final existing = _forceDataSources[id.toString()];

    if (existing != null) return existing;

    final dataSource = ForceDataSource(id: id.toString());

    dataSourceRegistry.register(dataSource);

    return dataSource;
  }

  void dispose() {
    _forceDataSources.values.forEach(_unregisterDataSource);
  }

  void _unregisterDataSource(DataSource dataSource) {
    dataSourceRegistry.unregister(dataSource.name);
  }
}