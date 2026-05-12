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
        await for (final point in stream) {
          if (!collecting && point.value >= threshold) {
            collecting = true;
            buffer.clear();
          }
          if (collecting) {
            buffer.add(point);
            if (point.value < threshold) collecting = false;
            yield buffer
                .map(
                  (p) => FlSpot(
                    p.timestamp.millisecondsSinceEpoch.toDouble(),
                    p.value,
                  ),
                )
                .toList(growable: false);
          }
        }
      });

  SinceThresholdTransformer({required this.yUnit, required this.threshold});
}
