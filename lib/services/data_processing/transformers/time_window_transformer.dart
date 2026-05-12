import 'dart:async';
import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_transformer.dart';

class TimeWindowTransformer extends DataTransformer {
  @override
  String get name => "Time Window";

  @override
  Unit get xUnit => Unit.s;

  @override
  Unit yUnit;

  final Duration duration;

  @override
  StreamTransformer<Measurement, List<FlSpot>> get transformer =>
      StreamTransformer.fromBind((stream) {
        final buffer = Queue<Measurement>();
        DateTime? origin;
        return stream.map((point) {
          origin ??= point.timestamp;
          buffer.addLast(point);
          final cutoff = point.timestamp.subtract(duration);
          while (buffer.isNotEmpty && buffer.first.timestamp.isBefore(cutoff)) {
            buffer.removeFirst();
          }
          return buffer
              .map((p) => FlSpot(_toXUnit(p.timestamp.difference(origin!).inMilliseconds.toDouble()), p.value))
              .toList(growable: false);
        });
      });

  double _toXUnit(double ms) => switch (xUnit) {
    Unit.ms => ms,
    Unit.s => ms / 1000.0,
    Unit.min => ms / 60000.0,
    _ => ms,
  };

  TimeWindowTransformer({required this.yUnit, required this.duration});
}
