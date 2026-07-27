import 'dart:async';

import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

import 'combinator.dart';
import 'point_collector.dart';
import 'point_filter.dart';
import 'unit_pair.dart';
import 'visualizer_param.dart';

/// Builds a [PointCollector] from the resolved parameter values of a widget.
typedef CollectorBuilder = PointCollector Function(Map<String, double> params);

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

  /// Numeric settings this visualizer exposes for per-widget configuration.
  List<VisualizerParam> get params;

  Map<String, double> resolveParams(Map<String, double> overrides) => {
    for (final p in params) p.key: p.clamp(overrides[p.key] ?? p.defaultValue),
  };
}

/// A visualizer that consumes exactly one [DataSource].
class Visualizer1 extends AnyVisualizer {
  @override
  final String name;

  @override
  int get sourceCount => 1;

  @override
  final List<VisualizerParam> params;

  final Combinator1 combinator;
  final List<PointFilter> filters;
  final CollectorBuilder buildCollector;

  Visualizer1({
    required this.name,
    required this.combinator,
    this.filters = const [],
    this.params = const [],
    required this.buildCollector,
  });

  BoundVisualizer bind(
    DataSource source, {
    Map<String, double> params = const {},
  }) {
    final collector = buildCollector(resolveParams(params));
    var stream = combinator.call(source.data);
    var units = combinator.units(source.unit);
    for (final f in filters) {
      stream = stream.transform(f.transformer);
      units = f.unitTransform(units);
    }
    return BoundVisualizer(
      name: name,
      units: collector.unitTransform(units),
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

  @override
  final List<VisualizerParam> params;

  final Combinator2 combinator;
  final List<PointFilter> filters;
  final CollectorBuilder buildCollector;

  Visualizer2({
    required this.name,
    required this.combinator,
    this.filters = const [],
    this.params = const [],
    required this.buildCollector,
  });

  BoundVisualizer bind(
    DataSource s1,
    DataSource s2, {
    Map<String, double> params = const {},
  }) {
    final collector = buildCollector(resolveParams(params));
    var stream = combinator.call(s1.data, s2.data);
    var units = combinator.units(s1.unit, s2.unit);
    for (final f in filters) {
      stream = stream.transform(f.transformer);
      units = f.unitTransform(units);
    }
    return BoundVisualizer(
      name: name,
      units: collector.unitTransform(units),
      output: stream.transform(collector.collector),
    );
  }
}
