import 'dart:async';

import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/point_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/unit_pair.dart';

/// Collects points since [XYPoint.y] first exceeds [threshold]. Stops
/// collecting (but keeps the buffer) when y drops below threshold again.
/// Re-triggers on the next crossing, clearing the previous buffer.
class SinceThresholdCollector extends PointCollector {
  final double threshold;

  SinceThresholdCollector(this.threshold);

  @override
  UnitPair Function(UnitPair) get unitTransform =>
      (u) => u;

  @override
  String? get idleHint =>
      'Nothing collected yet — starts when the value passes '
      '${threshold.toStringAsFixed(0)}.';

  @override
  StreamTransformer<XYPoint, List<XYPoint>> get collector =>
      StreamTransformer.fromBind((stream) async* {
        final buffer = <XYPoint>[];
        var collecting = false;
        await for (final point in stream) {
          if (!collecting && point.y >= threshold) {
            collecting = true;
            buffer.clear();
          }
          if (collecting) {
            buffer.add(point);
            if (point.y < threshold) collecting = false;
            yield List.unmodifiable(buffer);
          }
        }
      });
}
