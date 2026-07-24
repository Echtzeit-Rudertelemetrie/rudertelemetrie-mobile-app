import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/combinator.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/unit_pair.dart';

/// Maps a single data source to (elapsed time in [xUnit], measurement value).
/// Time is measured from the first received measurement.
class TimeElapsedCombinator extends Combinator1 {
  final Unit xUnit;

  TimeElapsedCombinator(this.xUnit);

  @override
  UnitPair units(Unit sourceUnit) => (x: xUnit, y: sourceUnit);

  @override
  Stream<XYPoint> call(Stream<Measurement> source) {
    return StreamTransformer<Measurement, XYPoint>.fromBind((stream) {
      DateTime? origin;
      return stream.map((m) {
        origin ??= m.timestamp;
        final elapsedMs = m.timestamp
            .difference(origin!)
            .inMilliseconds
            .toDouble();
        return XYPoint(
          x: _toXUnit(elapsedMs),
          y: m.value,
          timestamp: m.timestamp,
        );
      });
    }).bind(source);
  }

  double _toXUnit(double ms) => switch (xUnit) {
    Unit.ms => ms,
    Unit.s => ms / 1000.0,
    Unit.min => ms / 60000.0,
    _ => ms,
  };
}
