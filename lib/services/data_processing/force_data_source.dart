import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

class ForceDataSource extends DataSource {
  final StreamController<Measurement> _controller = StreamController();

  final String id;

  @override
  late final DateTime startTime;

  ForceDataSource({ required this.id }) {
    startTime = DateTime.now();
  }

  void add(Measurement value) {
    _controller.sink.add(value);
  }

  @override
  Stream<Measurement> get data => _controller.stream;

  @override
  void dispose() {
    _controller.close();
  }

  @override
  String get name => "Force $id";

  @override
  Unit get unit => Unit.N;
}