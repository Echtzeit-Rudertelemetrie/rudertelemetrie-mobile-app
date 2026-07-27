import 'dart:async';
import 'dart:collection';

import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/point_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/unit_pair.dart';

/// Accumulates one bar per incoming point (one per stroke, for a per-stroke
/// source), keeping a rolling window of the last [window] points. Emits the
/// current window on every point.
class PerStrokeBarCollector extends PointCollector {
  final int window;

  PerStrokeBarCollector(this.window);

  @override
  UnitPair Function(UnitPair) get unitTransform =>
      (u) => u;

  @override
  StreamTransformer<XYPoint, List<XYPoint>> get collector =>
      StreamTransformer.fromBind((stream) {
        final buffer = Queue<XYPoint>();
        return stream.map((point) {
          buffer.addLast(point);
          while (buffer.length > window) {
            buffer.removeFirst();
          }
          return List<XYPoint>.unmodifiable(buffer);
        });
      });
}
