import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/unit_pair.dart';

/// Maps each measurement to (incrementing stroke index, value). Intended for
/// per-stroke sources that emit exactly one [Measurement] per stroke, so the
/// index is the stroke number.
class StrokeIndexCombinator extends Combinator1 {
  @override
  UnitPair units(Unit sourceUnit) => (x: Unit.count, y: sourceUnit);

  @override
  Stream<XYPoint> call(Stream<Measurement> source) {
    return StreamTransformer<Measurement, XYPoint>.fromBind((stream) {
      var index = 0;
      return stream.map(
        (m) => XYPoint(
          x: (index++).toDouble(),
          y: m.value,
          timestamp: m.timestamp,
        ),
      );
    }).bind(source);
  }
}
