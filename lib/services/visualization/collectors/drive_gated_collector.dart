import 'dart:async';

import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/point_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/unit_pair.dart';

/// Collects points over one drive, segmented on catch→finish with the same
/// force hysteresis the stroke engine uses (stroke-detection §2.1): begins a
/// fresh buffer when force ([XYPoint.y]) rises through [fOn] (catch) and stops
/// when it falls through [fOff] (finish). Upgrades the single-threshold
/// [SinceThresholdCollector] the legacy force/angle curve used, so the curve is
/// segmented on true drive boundaries instead of chattering at one level.
class DriveGatedCollector extends PointCollector {
  final double fOn;
  final double fOff;

  DriveGatedCollector({required this.fOn, required this.fOff});

  @override
  UnitPair Function(UnitPair) get unitTransform => (u) => u;

  @override
  StreamTransformer<XYPoint, List<XYPoint>> get collector =>
      StreamTransformer.fromBind((stream) async* {
        final buffer = <XYPoint>[];
        var inDrive = false;
        await for (final point in stream) {
          if (!inDrive && point.y >= fOn) {
            inDrive = true;
            buffer.clear();
          }
          if (inDrive) {
            buffer.add(point);
            if (point.y < fOff) inDrive = false;
            yield List<XYPoint>.unmodifiable(buffer);
          }
        }
      });
}
