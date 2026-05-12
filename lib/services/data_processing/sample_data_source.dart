import 'dart:async';
import 'dart:math';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

class SampleDataSource implements DataSource {
  @override
  late final Stream<Measurement> data;

  late DateTime _start;
  Timer? _timer;

  /// Period of the sine wave in seconds.
  static const double _periodSeconds = 5.0;

  SampleDataSource() {
    final controller = StreamController<Measurement>.broadcast();
    data = controller.stream;
    _start = DateTime.now();

    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final elapsed = DateTime.now().difference(_start).inMilliseconds / 1000.0;
      final value = 50 + 50 * sin(2 * pi * elapsed / _periodSeconds);
      controller.add(Measurement(timestamp: DateTime.now(), value: value));
    });
  }

  @override
  void dispose() => _timer?.cancel();

  @override
  String get name => "Sample";

  @override
  Unit get unit => Unit.N;

  @override
  DateTime get startTime => _start;
}