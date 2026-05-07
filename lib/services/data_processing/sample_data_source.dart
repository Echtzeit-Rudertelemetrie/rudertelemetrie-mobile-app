import 'dart:async';
import 'dart:math';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

class SampleDataSource implements DataSource {
  @override
  late final Stream<Measurement> data;

  Timer? _timer;

  SampleDataSource() {
    final controller = StreamController<Measurement>.broadcast();
    data = controller.stream;

    _timer = Timer.periodic(Duration(milliseconds: 16), (_) {
      controller.add(Measurement(
        timestamp: DateTime.now(),
        value: Random().nextDouble() * 100,
      ));
    });
  }

  @override
  void dispose() => _timer?.cancel();

  @override
  String get name => "Sample";

  @override
  Unit get unit => Unit.N;
}