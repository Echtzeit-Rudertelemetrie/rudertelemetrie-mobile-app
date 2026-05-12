import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_transformer.dart';

class SinceThresholdTransformer extends DataTransformer {
  @override
  String get name => "Since Threshold";

  @override
  Unit get xUnit => Unit.s;

  @override
  Unit yUnit;

  final double threshold;

  @override
  StreamTransformer<Measurement, List<FlSpot>> get transformer =>
      StreamTransformer.fromBind((stream) async* {
        final buffer = <Measurement>[];
        var collecting = false;
        DateTime? origin;
        await for (final point in stream) {
          if (!collecting && point.value >= threshold) {
            collecting = true;
            buffer.clear();
            origin = point.timestamp;
          }
          if (collecting) {
            buffer.add(point);
            if (point.value < threshold) collecting = false;
            yield buffer
                .map((p) => FlSpot(_toXUnit(p.timestamp.difference(origin!).inMilliseconds.toDouble()), p.value))
                .toList(growable: false);
          }
        }
      });

  double _toXUnit(double ms) => switch (xUnit) {
    Unit.ms => ms,
    Unit.s => ms / 1000.0,
    Unit.min => ms / 60000.0,
    _ => ms,
  };

  SinceThresholdTransformer({required this.yUnit, required this.threshold});
}
