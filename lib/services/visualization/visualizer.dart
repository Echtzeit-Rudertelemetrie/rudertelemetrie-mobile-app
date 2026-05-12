import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

import 'combinator.dart';
import 'point_collector.dart';
import 'point_filter.dart';
import 'unit_pair.dart';

/// The result of binding a [Visualizer] to concrete [DataSource] instances.
/// Holds the final [units] and a ready-to-subscribe [output] stream.
class BoundVisualizer {
  final String name;
  final UnitPair units;
  final Stream<List<XYPoint>> output;

  const BoundVisualizer({
    required this.name,
    required this.units,
    required this.output,
  });
}

/// Base class for all visualizers. Use [Visualizer1] or [Visualizer2] directly.
sealed class AnyVisualizer {
  String get name;
  int get sourceCount;
}

/// A visualizer that consumes exactly one [DataSource].
class Visualizer1 extends AnyVisualizer {
  @override
  final String name;

  @override
  int get sourceCount => 1;

  final Combinator1 combinator;
  final List<PointFilter> filters;
  final PointCollector collector;

  Visualizer1({
    required this.name,
    required this.combinator,
    this.filters = const [],
    required this.collector,
  });

  UnitPair unitsFor(Unit sourceUnit) {
    var u = combinator.units(sourceUnit);
    for (final f in filters) {
      u = f.unitTransform(u);
    }
    return collector.unitTransform(u);
  }

  BoundVisualizer bind(DataSource source) {
    var stream = combinator.call(source.data);
    for (final f in filters) {
      stream = stream.transform(f.transformer);
    }
    return BoundVisualizer(
      name: name,
      units: unitsFor(source.unit),
      output: stream.transform(collector.collector),
    );
  }
}

/// A visualizer that consumes exactly two [DataSource]s.
class Visualizer2 extends AnyVisualizer {
  @override
  final String name;

  @override
  int get sourceCount => 2;

  final Combinator2 combinator;
  final List<PointFilter> filters;
  final PointCollector collector;

  Visualizer2({
    required this.name,
    required this.combinator,
    this.filters = const [],
    required this.collector,
  });

  UnitPair unitsFor(Unit s1Unit, Unit s2Unit) {
    var u = combinator.units(s1Unit, s2Unit);
    for (final f in filters) {
      u = f.unitTransform(u);
    }
    return collector.unitTransform(u);
  }

  BoundVisualizer bind(DataSource s1, DataSource s2) {
    var stream = combinator.call(s1.data, s2.data);
    for (final f in filters) {
      stream = stream.transform(f.transformer);
    }
    return BoundVisualizer(
      name: name,
      units: unitsFor(s1.unit, s2.unit),
      output: stream.transform(collector.collector),
    );
  }
}
