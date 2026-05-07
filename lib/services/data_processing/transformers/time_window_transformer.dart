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
        return stream.map((point) {
          buffer.addLast(point);
          final cutoff = point.timestamp.subtract(duration);
          while (buffer.isNotEmpty && buffer.first.timestamp.isBefore(cutoff)) {
            buffer.removeFirst();
          }
          return buffer
              .map(
                (p) => FlSpot(
                  p.timestamp.millisecondsSinceEpoch.toDouble(),
                  p.value,
                ),
              )
              .toList(growable: false);
        });
      });

  TimeWindowTransformer({required this.yUnit, required this.duration});
}
