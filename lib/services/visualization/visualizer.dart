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

enum SourceSelectionMode { individual, forceAnglePair }

/// The shape of the points a visualizer produces. A tile declares which shapes
/// it can draw, so the sheet can offer only the visualizers that suit the tile
/// the user picked — without the pipeline knowing tiles exist.
enum VisualizerShape {
  /// A value against elapsed time, advancing continuously.
  series,

  /// One value against another, tracing a curve.
  xy,

  /// One point per completed stroke.
  perStroke,
}

/// The result of binding a [Visualizer] to concrete [DataSource] instances.
/// Holds the final [units] and a ready-to-subscribe [output] stream.
///
/// A binding outlives the widget that shows it — `VisualizerBindingCache` keeps
/// it across edit-mode toggles, drags and preset switches precisely so the
/// accumulated history survives, and a tile remounts freely underneath it. The
/// pipeline itself does not allow that: the gated collectors are `async*`
/// generators, so their stream can be listened to exactly once. So the raw
/// pipeline is subscribed at most once here and fanned out to however many
/// tiles are watching, with the last emission replayed to a tile that mounts
/// late — otherwise a remounted chart would sit empty until the next point,
/// which for a per-stroke source is a whole stroke away.
class BoundVisualizer {
  final String name;
  final UnitPair units;
  final ({double min, double max})? fixedXBounds;

  /// What this binding is waiting for while it has produced nothing — a stroke,
  /// a drive, a recording. Null when points should simply arrive.
  final String? idleHint;

  /// The data source(s) feeding this binding, named as the user picked them.
  /// A tile that has nothing to draw yet shows this, so an empty tile still
  /// says which stream it is bound to.
  final String? sourceLabel;

  final Stream<List<XYPoint>> _pipeline;
  final StreamController<List<XYPoint>> _fanout =
      StreamController<List<XYPoint>>.broadcast();

  StreamSubscription<List<XYPoint>>? _subscription;
  List<XYPoint>? _latest;

  BoundVisualizer({
    required this.name,
    required this.units,
    required Stream<List<XYPoint>> output,
    this.fixedXBounds,
    this.idleHint,
    this.sourceLabel,
  }) : _pipeline = output;

  /// A fresh subscription per listener. Emits the most recent points first when
  /// there are any, then everything that follows.
  Stream<List<XYPoint>> get output => Stream.multi((controller) {
    _start();
    final latest = _latest;
    if (latest != null) controller.add(latest);
    final subscription = _fanout.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });

  /// Deferred to the first listener: a dashboard holds bindings for tiles that
  /// may never be built, and an unwatched pipeline should not run.
  void _start() {
    _subscription ??= _pipeline.listen(
      (points) {
        _latest = points;
        _fanout.add(points);
      },
      onError: _fanout.addError,
      onDone: _fanout.close,
    );
  }

  /// Releases the upstream subscription. The binding is unusable afterwards;
  /// its owner ([VisualizerBindingCache]) calls this when it drops the binding.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    if (!_fanout.isClosed) _fanout.close();
  }
}

/// The gate a tile is waiting on: the collector's own, or failing that the one
/// declared by a source that only speaks under some condition. The collector
/// wins — it is the narrower gate, and the last one the points pass through.
String? resolveIdleHint(PointCollector collector, List<DataSource> sources) =>
    collector.idleHint ?? sources.map((s) => s.idleHint).nonNulls.firstOrNull;

/// Names the sources a binding reads, as one line for a tile to show.
String sourceLabelOf(List<DataSource> sources) =>
    sources.map((s) => s.name).join(' · ');

/// Base class for all visualizers. Use [Visualizer1] or [Visualizer2] directly.
sealed class AnyVisualizer {
  String get name;
  int get sourceCount;
  SourceSelectionMode get sourceSelectionMode;

  /// One line on how this visualizer shapes its sources, for the picker.
  String get description;

  VisualizerShape get shape;

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
  final String description;

  @override
  final VisualizerShape shape;

  @override
  int get sourceCount => 1;

  @override
  final SourceSelectionMode sourceSelectionMode;

  @override
  final List<VisualizerParam> params;

  final Combinator1 combinator;
  final List<PointFilter> filters;
  final CollectorBuilder buildCollector;
  final ({double min, double max})? fixedXBounds;

  Visualizer1({
    required this.name,
    required this.description,
    required this.shape,
    required this.combinator,
    this.filters = const [],
    this.params = const [],
    required this.buildCollector,
    this.fixedXBounds,
    this.sourceSelectionMode = SourceSelectionMode.individual,
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
      fixedXBounds: fixedXBounds,
      idleHint: resolveIdleHint(collector, [source]),
      sourceLabel: sourceLabelOf([source]),
    );
  }
}

/// A visualizer that consumes exactly two [DataSource]s.
class Visualizer2 extends AnyVisualizer {
  @override
  final String name;

  @override
  final String description;

  @override
  final VisualizerShape shape;

  @override
  int get sourceCount => 2;

  @override
  final SourceSelectionMode sourceSelectionMode;

  @override
  final List<VisualizerParam> params;

  final Combinator2 combinator;
  final List<PointFilter> filters;
  final CollectorBuilder buildCollector;
  final ({double min, double max})? fixedXBounds;

  Visualizer2({
    required this.name,
    required this.description,
    required this.shape,
    required this.combinator,
    this.filters = const [],
    this.params = const [],
    required this.buildCollector,
    this.fixedXBounds,
    this.sourceSelectionMode = SourceSelectionMode.individual,
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
      fixedXBounds: fixedXBounds,
      idleHint: resolveIdleHint(collector, [s1, s2]),
      sourceLabel: sourceLabelOf([s1, s2]),
    );
  }
}
