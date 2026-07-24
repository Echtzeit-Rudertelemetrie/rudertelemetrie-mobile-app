import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/unit_pair.dart';

/// Maps two data sources to (source1.value, source2.value).
class ValueVsValueCombinator extends Combinator2 {
  /// When true, only samples with identical timestamps are paired. This is
  /// useful for force/angle values originating from the same firmware packet.
  /// Other XY visualizers retain combine-latest behavior by default.
  final bool requireMatchingTimestamps;

  ValueVsValueCombinator({this.requireMatchingTimestamps = false});

  @override
  UnitPair units(Unit s1Unit, Unit s2Unit) => (x: s1Unit, y: s2Unit);

  @override
  Stream<XYPoint> call(Stream<Measurement> s1, Stream<Measurement> s2) {
    return Stream.multi((controller) {
      Measurement? latest1;
      Measurement? latest2;
      StreamSubscription<Measurement>? sub1;
      StreamSubscription<Measurement>? sub2;

      DateTime? lastEmittedTimestamp;

      void tryEmit() {
        if (latest1 == null || latest2 == null) return;
        if (requireMatchingTimestamps &&
            latest1!.timestamp != latest2!.timestamp) {
          return;
        }
        final ts = latest1!.timestamp.isAfter(latest2!.timestamp)
            ? latest1!.timestamp
            : latest2!.timestamp;
        if (ts == lastEmittedTimestamp) {
          return;
        }
        lastEmittedTimestamp = ts;
        controller.add(
          XYPoint(x: latest1!.value, y: latest2!.value, timestamp: ts),
        );
      }

      sub1 = s1.listen(
        (m) {
          latest1 = m;
          tryEmit();
        },
        onError: controller.addError,
        onDone: () {
          sub2?.cancel();
          controller.close();
        },
      );

      sub2 = s2.listen(
        (m) {
          latest2 = m;
          tryEmit();
        },
        onError: controller.addError,
        onDone: () {
          sub1?.cancel();
          controller.close();
        },
      );

      controller.onCancel = () {
        sub1?.cancel();
        sub2?.cancel();
      };
    });
  }
}
