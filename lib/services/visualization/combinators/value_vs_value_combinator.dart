import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/unit_pair.dart';

/// Maps two data sources to (source1.value, source2.value) using combine-latest
/// semantics: emits a new point whenever either source produces a measurement,
/// using the most recent value from the other source.
class ValueVsValueCombinator extends Combinator2 {
  @override
  UnitPair units(Unit s1Unit, Unit s2Unit) => (x: s1Unit, y: s2Unit);

  @override
  Stream<XYPoint> call(Stream<Measurement> s1, Stream<Measurement> s2) {
    return Stream.multi((controller) {
      Measurement? latest1;
      Measurement? latest2;
      StreamSubscription<Measurement>? sub1;
      StreamSubscription<Measurement>? sub2;

      void tryEmit() {
        if (latest1 == null || latest2 == null) return;
        final ts = latest1!.timestamp.isAfter(latest2!.timestamp)
            ? latest1!.timestamp
            : latest2!.timestamp;
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
