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

  BluetoothStreamHandler({required this.dataSourceRegistry});

  void onPacket(List<int> raw) {
    final packet = BluetoothPacket.decode(raw);
    if (packet == null) return;

    final idCounters = <int, int>{};

    for (final reading in packet.readings) {
      final readingIndex = idCounters[reading.sensorId] ?? 0;
      idCounters[reading.sensorId] = readingIndex + 1;

      switch (reading) {
        case OarlockReading():
          _emitOarlockValue(packet.sequenceNumber, reading, readingIndex);
        case BoatReading():
          break;
      }
    }
  }

  void _emitOarlockValue(
    int packetSequenceNumber,
    OarlockReading reading,
    int readingIndex,
  ) {
    final dataSource = _ensureForceDataSourceExists(reading.sensorId);

    final value = convertForceSensorData(reading.force);
    final timestamp = convertSequenceNumbersToTimestamp(
      dataSource.startTime,
      packetSequenceNumber,
      readingIndex,
    );

    dataSource.add(Measurement(value: value, timestamp: timestamp));
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
