import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/models/speed_settings_model.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

/// GPS speed source whose public value and unit follow the global speed setting.
/// Incoming firmware values always remain SI (m/s).
class SpeedDataSource extends DataSource {
  final StreamController<Measurement> _controller =
      StreamController.broadcast();
  final SpeedSettingsModel settings;

  @override
  final String name;

  @override
  final String? group;

  @override
  late final DateTime startTime;

  SpeedDataSource({required this.name, required this.settings, this.group}) {
    startTime = DateTime.now();
  }

  @override
  Unit get unit => settings.unit;

  void addMps(Measurement measurement) {
    _controller.add(
      Measurement(
        value: settings.convertFromMps(measurement.value),
        timestamp: measurement.timestamp,
      ),
    );
  }

  @override
  Stream<Measurement> get data => _controller.stream;

  @override
  void dispose() => _controller.close();
}
