import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

/// A data source whose measurements are pushed in from the outside (e.g. a
/// decoded Bluetooth packet). Broadcasts so multiple dashboard tiles can observe
/// the same stream.
class PushDataSource extends DataSource {
  final StreamController<Measurement> _controller =
      StreamController.broadcast();

  @override
  final String name;

  @override
  final Unit unit;

  @override
  final String? group;

  @override
  late final DateTime startTime;

  PushDataSource({required this.name, required this.unit, this.group}) {
    startTime = DateTime.now();
  }

  void add(Measurement value) => _controller.sink.add(value);

  @override
  Stream<Measurement> get data => _controller.stream;

  @override
  void dispose() => _controller.close();
}
