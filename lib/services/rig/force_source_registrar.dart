import 'dart:async';

import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/force_sources.dart';

final _baseForce = RegExp(r'^Force \d');
final _baseAngle = RegExp(r'^Angle \d');

/// Keeps the derived force sources in sync with the connected oarlocks and their
/// rig config. A per-oarlock set registers only once that oarlock has both its
/// `Force`/`Angle` sources and a valid rig (force-power-derived "hard gate"),
/// and re-registers when the rig changes. Reconciliation is coalesced into a
/// microtask so registration during a notify never re-enters synchronously.
class ForceSourceRegistrar {
  final DataSourceRegistry registry;
  final BoatConfig config;

  final Map<String, _BuiltSet> _built = {};
  bool _scheduled = false;
  bool _disposed = false;

  ForceSourceRegistrar({required this.registry, required this.config}) {
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

    for (final key in _built.keys.toList()) {
      final pair = oarlocks[key];
      final rig = config.rigFor(key);
      final stale = pair == null ||
          rig == null ||
          !rig.isValid ||
          _built[key]!.signature != _signature(rig);
      if (stale) _remove(key);
    }

    oarlocks.forEach((key, pair) {
      if (_built.containsKey(key)) return;
      final rig = config.rigFor(key);
      if (rig == null || !rig.isValid) return;
      final sources = buildForceSources(
        force: pair.force,
        angle: pair.angle,
        rig: rig,
        oarlockKey: key,
      );
      for (final source in sources) {
        registry.registerDeferred(source);
      }
      _built[key] = _BuiltSet(_signature(rig), sources);
    });
  }

  Map<String, _OarlockPair> _presentOarlocks() {
    final forces = <String, DataSource>{};
    final angles = <String, DataSource>{};
    for (final source in registry.all) {
      if (_baseForce.hasMatch(source.name)) {
        forces[source.name.replaceFirst('Force ', '')] = source;
      } else if (_baseAngle.hasMatch(source.name)) {
        angles[source.name.replaceFirst('Angle ', '')] = source;
      }
    }

    final pairs = <String, _OarlockPair>{};
    forces.forEach((suffix, force) {
      final angle = angles[suffix];
      final key = force.group;
      if (angle != null && key != null) {
        pairs[key] = _OarlockPair(force, angle);
      }
    });
    return pairs;
  }

  String _signature(RigConfig rig) => '${rig.innerLever}_${rig.scullLength}';

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

class _OarlockPair {
  final DataSource force;
  final DataSource angle;
  _OarlockPair(this.force, this.angle);
}

class _BuiltSet {
  final String signature;
  final List<DataSource> sources;
  _BuiltSet(this.signature, this.sources);
}
