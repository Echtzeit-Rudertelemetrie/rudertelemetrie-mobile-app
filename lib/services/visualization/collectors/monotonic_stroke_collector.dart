import 'dart:async';

import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/point_collector.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/unit_pair.dart';

/// Builds one force-over-angle curve for the current rowing drive.
///
/// A drive starts when force crosses [forceThreshold] upwards and ends when it
/// falls below it. During the drive, only increasing angles are retained.
/// Sensor jitter and the right-to-left recovery therefore cannot make the
/// plotted curve run backwards.
class MonotonicStrokeCollector extends PointCollector {
  final double forceThreshold;
  final double maxUnconfirmedAngleStep;

  MonotonicStrokeCollector({
    required this.forceThreshold,
    this.maxUnconfirmedAngleStep = 5,
  });

  @override
  UnitPair Function(UnitPair) get unitTransform =>
      (units) => units;

  @override
  StreamTransformer<XYPoint, List<XYPoint>> get collector =>
      StreamTransformer.fromBind((stream) async* {
        final stroke = <XYPoint>[];
        var displayedStroke = <XYPoint>[];
        var driving = false;
        double? furthestAngle;
        XYPoint? pendingJump;

        await for (final point in stream) {
          if (!driving) {
            if (point.y < forceThreshold) continue;
            driving = true;
            stroke
              ..clear()
              ..add(point);
            furthestAngle = point.x;
            pendingJump = null;
            // Keep showing the completed stroke until the new one contains a
            // drawable line. A single point is invisible with dots disabled.
            if (displayedStroke.isEmpty) {
              yield List.unmodifiable(stroke);
            }
            continue;
          }

          if (point.y < forceThreshold) {
            driving = false;
            furthestAngle = null;
            pendingJump = null;
            continue;
          }

          if (point.x <= furthestAngle!) continue;

          final step = point.x - furthestAngle;
          if (step > maxUnconfirmedAngleStep) {
            final pending = pendingJump;
            if (pending == null ||
                point.x < pending.x ||
                point.x - pending.x > maxUnconfirmedAngleStep) {
              pendingJump = point;
              continue;
            }
            // Two consecutive forward samples confirm that this was a genuine
            // fast movement or a transport gap rather than a one-sample spike.
          }

          pendingJump = null;
          furthestAngle = point.x;
          stroke.add(point);
          if (stroke.length >= 2) {
            displayedStroke = List.unmodifiable(stroke);
            yield displayedStroke;
          }
        }
      });
}
