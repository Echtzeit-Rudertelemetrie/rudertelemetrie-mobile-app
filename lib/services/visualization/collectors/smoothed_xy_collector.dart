import 'dart:async';

import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/point_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/unit_pair.dart';

/// Wraps another [PointCollector] and turns its buffer into a clean, single-
/// valued X/Y curve: keeps only the newest point per x, drops points older than
/// [maxAge] relative to the latest one (stale leftovers from an earlier stroke),
/// and emits sorted by x.
class SmoothedXyCollector extends PointCollector {
  final PointCollector inner;
  final Duration maxAge;

  SmoothedXyCollector(this.inner, {required this.maxAge});

  @override
  UnitPair Function(UnitPair) get unitTransform => inner.unitTransform;

  @override
  String? get idleHint => inner.idleHint;

  @override
  StreamTransformer<XYPoint, List<XYPoint>> get collector =>
      StreamTransformer.fromBind(
        (stream) => stream.transform(inner.collector).map(_smooth),
      );

  List<XYPoint> _smooth(List<XYPoint> points) {
    if (points.isEmpty) return points;

    final latestByX = <double, XYPoint>{};
    var newest = points.first.timestamp;
    for (final p in points) {
      if (p.timestamp.isAfter(newest)) newest = p.timestamp;
      final existing = latestByX[p.x];
      if (existing == null || p.timestamp.isAfter(existing.timestamp)) {
        latestByX[p.x] = p;
      }
    }

    final cutoff = newest.subtract(maxAge);
    final fresh =
        latestByX.values.where((p) => !p.timestamp.isBefore(cutoff)).toList()
          ..sort((a, b) => a.x.compareTo(b.x));
    return List.unmodifiable(fresh);
  }
}
