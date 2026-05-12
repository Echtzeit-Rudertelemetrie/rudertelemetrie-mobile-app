import 'dart:async';
import 'dart:math';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

class SampleDataSource implements DataSource {
  @override
  late final Stream<Measurement> data;

  Timer? _timer;

  /// Period of the sine wave in seconds.
  static const double _periodSeconds = 5.0;

  SampleDataSource() {
    final controller = StreamController<Measurement>.broadcast();
    data = controller.stream;
    final start = DateTime.now();

    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final elapsed = DateTime.now().difference(start).inMilliseconds / 1000.0;
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
}