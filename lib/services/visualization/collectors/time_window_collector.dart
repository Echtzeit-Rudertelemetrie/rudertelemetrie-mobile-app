import 'dart:async';
import 'dart:collection';

import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/point_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/unit_pair.dart';

/// Keeps all points whose [XYPoint.timestamp] falls within [duration] before
/// the latest received point. Emits the current window as an unmodifiable list
/// on every incoming point.
class TimeWindowCollector extends PointCollector {
  final Duration duration;

  TimeWindowCollector(this.duration);

  @override
  UnitPair Function(UnitPair) get unitTransform =>
      (u) => u;

  @override
  StreamTransformer<XYPoint, List<XYPoint>> get collector =>
      StreamTransformer.fromBind((stream) {
        final buffer = Queue<XYPoint>();
        return stream.map((point) {
          buffer.addLast(point);
          final cutoff = point.timestamp.subtract(duration);
          while (buffer.isNotEmpty && buffer.first.timestamp.isBefore(cutoff)) {
            buffer.removeFirst();
          }
          return List.unmodifiable(buffer);
        });
      });
}
