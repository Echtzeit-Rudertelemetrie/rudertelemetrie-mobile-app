import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/angular_velocity_source.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/force_sources.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_aggregate_source.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_engine.dart';

final _baseForce = RegExp(r'^Force \d');
final _baseAngle = RegExp(r'^Angle \d');
const _speedSource = 'Speed (km/h)';

/// Registers the Phase 3 power sources per oarlock (force-power §2-4, §6): the
/// shared ω source, the instantaneous power/slip/efficiency sources, and the
/// per-stroke aggregates gated on the stroke engine's events. Gated on rig like
/// the Phase 1 force sources; the propulsion metrics also require the boat
/// `Speed` source. Reconciliation is coalesced into a microtask.
class PowerSourceRegistrar {
  final DataSourceRegistry registry;
  final BoatConfig config;
  final StrokeEngine engine;

  final Map<String, _BuiltSet> _built = {};
  bool _scheduled = false;
  bool _disposed = false;

  PowerSourceRegistrar({
    required this.registry,
    required this.config,
    required this.engine,
  }) {
    registry.addListener(_schedule);
    config.addListener(_schedule);
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed) _reconcile();
    });
  }

  void _reconcile() {
    final oarlocks = _presentOarlocks();
    final speed = registry.get(_speedSource);

    for (final key in _built.keys.toList()) {
      final pair = oarlocks[key];
      final rig = config.rigFor(key);
      final stale =
          pair == null ||
          rig == null ||
          !rig.isValid ||
          _built[key]!.signature != _signature(rig, speed != null);
      if (stale) _remove(key);
    }

    oarlocks.forEach((key, pair) {
      if (_built.containsKey(key)) return;
      final rig = config.rigFor(key);
      if (rig == null || !rig.isValid) return;
      _build(key, pair, rig, speed);
    });
  }

  void _build(String key, _SourcePair pair, RigConfig rig, DataSource? speed) {
    final suffix = pair.force.name.replaceFirst('Force ', '');
    final group = 'Force & Power ($key)';

    final omega = AngularVelocitySource(
      name: 'Angular Velocity $suffix',
      angle: pair.angle,
      group: group,
    );
    final power = buildPowerSources(
      force: pair.force,
      angle: pair.angle,
      omega: omega,
      speedKmh: speed,
      rig: rig,
      oarlockKey: key,
    );

    final powerSource = power.firstWhere((s) => s.name.startsWith('Power '));
    final slip = power.where((s) => s.name.startsWith('Blade Slip ')).toList();

    final aggregates = <DataSource>[
      _aggregate(
        'Avg Power / Stroke $suffix',
        Unit.W,
        powerSource,
        key,
        group,
        StrokeAggregate.averageOverCycle,
      ),
      _aggregate(
        'Peak Power / Stroke $suffix',
        Unit.W,
        powerSource,
        key,
        group,
        StrokeAggregate.peakOverCycle,
      ),
      _aggregate(
        'Work / Stroke $suffix',
        Unit.J,
        powerSource,
        key,
        group,
        StrokeAggregate.integralOverCycle,
      ),
      _aggregate(
        'Avg Drive Force $suffix',
        Unit.N,
        pair.force,
        key,
        group,
        StrokeAggregate.averageOverDrive,
      ),
      _aggregate(
        'Peak Force / Stroke $suffix',
        Unit.N,
        pair.force,
        key,
        group,
        StrokeAggregate.peakOverDrive,
      ),
      if (slip.isNotEmpty)
        _aggregate(
          'Blade Drift / Stroke $suffix',
          Unit.m,
          slip.first,
          key,
          group,
          StrokeAggregate.integralOverDrive,
        ),
    ];

    final all = [omega, ...power, ...aggregates];
    for (final source in all) {
      registry.registerDeferred(source);
    }
    _built[key] = _BuiltSet(_signature(rig, speed != null), all);
  }

  StrokeGatedAggregateSource _aggregate(
    String name,
    Unit unit,
    DataSource base,
    String oarlockKey,
    String group,
    StrokeAggregate mode,
  ) => StrokeGatedAggregateSource(
    name: name,
    unit: unit,
    base: base,
    events: engine.events,
    oarlockKey: oarlockKey,
    mode: mode,
    group: group,
  );

  Map<String, _SourcePair> _presentOarlocks() {
    final forces = <String, DataSource>{};
    final angles = <String, DataSource>{};
    for (final source in registry.all) {
      if (_baseForce.hasMatch(source.name)) {
        forces[source.name.replaceFirst('Force ', '')] = source;
      } else if (_baseAngle.hasMatch(source.name)) {
        angles[source.name.replaceFirst('Angle ', '')] = source;
      }
    }
    final pairs = <String, _SourcePair>{};
    forces.forEach((suffix, force) {
      final angle = angles[suffix];
      final key = force.group;
      if (angle != null && key != null) pairs[key] = _SourcePair(force, angle);
    });
    return pairs;
  }

  String _signature(RigConfig rig, bool hasSpeed) =>
      '${rig.innerLever}_${rig.scullLength}_$hasSpeed';

  void _remove(String key) {
    final built = _built.remove(key);
    if (built == null) return;
    for (final source in built.sources) {
      registry.unregister(source.name);
      source.dispose();
    }
  }

  void dispose() {
    _disposed = true;
    registry.removeListener(_schedule);
    config.removeListener(_schedule);
    for (final key in _built.keys.toList()) {
      _remove(key);
    }
  }
}

class _SourcePair {
  final DataSource force;
  final DataSource angle;
  _SourcePair(this.force, this.angle);
}

class _BuiltSet {
  final String signature;
  final List<DataSource> sources;
  _BuiltSet(this.signature, this.sources);
}
