import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/oarlock_stroke_detector.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_event.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_settings.dart';

final _baseForce = RegExp(r'^Force \d');
final _baseAngle = RegExp(r'^Angle \d');

/// Cross-cutting stroke segmentation (stroke-engine spec). Binds each oarlock's
/// `Force`/`Angle` sources, runs a per-oarlock detector, aggregates to crew
/// level, and registers the per-stroke derived sources. Also emits a "rowing"
/// signal used for the recording session's auto-start/stop.
class StrokeEngine {
  /// How long to wait for the rest of the crew after the first oarlock closes a
  /// cycle. Finishes are spread across a real crew, not simultaneous; waiting
  /// indefinitely for a rower who has stopped freezes every crew metric.
  static const defaultQuorumWindow = Duration(milliseconds: 1500);

  final DataSourceRegistry registry;
  final StrokeSettings settings;
  final RecordingSession? session;
  final Duration quorumWindow;

  final StreamController<StrokeEvent> _events = StreamController.broadcast();
  final Map<String, _OarlockBinding> _bindings = {};
  final Map<String, OarlockCycle> _pending = {};
  Timer? _quorumTimer;

  late final PushDataSource _rate;
  late final PushDataSource _count;
  late final PushDataSource _ratio;
  late final PushDataSource _reversalToCatch;
  late final PushDataSource _distance;
  late final PushDataSource _catchAngle;
  late final PushDataSource _finishAngle;
  late final PushDataSource _sweep;
  late final PushDataSource _crewSync;
  late final PushDataSource _reporting;

  int _strokeCount = 0;
  double? _lastDistanceSnapshot;
  DateTime? _sessionOrigin;
  bool _scheduled = false;
  bool _disposed = false;
  bool _paused = false;

  StrokeEngine({
    required this.registry,
    required this.settings,
    this.session,
    this.quorumWindow = defaultQuorumWindow,
  }) {
    _rate = _register('Stroke Rate', Unit.spm);
    _count = _register('Stroke Count', Unit.count);
    _ratio = _register('Drive:Recovery Ratio', Unit.ratio);
    _reversalToCatch = _register('Reversal→Catch Time', Unit.s);
    _distance = _register('Distance per Stroke', Unit.m);
    _catchAngle = _register('Catch Angle', Unit.deg);
    _finishAngle = _register('Finish Angle', Unit.deg);
    _sweep = _register('Sweep', Unit.deg);
    _crewSync = _register('Crew Sync (finish)', Unit.s);
    _reporting = _register('Oarlocks Rowing', Unit.count);

    _sessionOrigin = session?.startedAt;
    session?.addListener(_onSession);
    registry.addListener(_schedule);
    settings.addListener(_schedule);
    _schedule();
  }

  Stream<StrokeEvent> get events => _events.stream;

  bool get isPaused => _paused;

  /// Suspends segmentation while a load cell is being calibrated. Hanging a
  /// known weight on a sensor otherwise reads as an enormous stroke: it would
  /// poison the auto-scaled peak, add a phantom to the count, and — through
  /// `onRowingDetected` — start a recording.
  ///
  /// The whole engine pauses rather than just the oarlock being calibrated,
  /// because one silent detector leaves crew aggregation waiting on it until the
  /// quorum window closes on a stroke nobody rowed.
  void pause() {
    if (_paused) return;
    _paused = true;
    _pending.clear();
    _quorumTimer?.cancel();
    _quorumTimer = null;
  }

  /// Detectors restart from scratch: the force reference they were segmenting
  /// against has moved, and the gap is not a recovery.
  void resume() {
    if (!_paused) return;
    _paused = false;
    for (final binding in _bindings.values) {
      binding.detector.reset();
    }
  }

  void _onSession() {
    if (session!.startedAt != _sessionOrigin) {
      _sessionOrigin = session!.startedAt;
      _strokeCount = 0;
      _lastDistanceSnapshot = null;
    }
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed) _rebind();
    });
  }

  void _rebind() {
    final oarlocks = _presentOarlocks();

    for (final key in _bindings.keys.toList()) {
      if (!oarlocks.containsKey(key)) {
        _bindings.remove(key)!.dispose();
        _pending.remove(key);
      }
    }

    oarlocks.forEach((key, pair) {
      final existing = _bindings[key];
      if (existing != null && existing.matches(pair.force, pair.angle)) return;
      existing?.dispose();
      _bindings[key] = _OarlockBinding(
        force: pair.force,
        angle: pair.angle,
        isPaused: () => _paused,
        detector: OarlockStrokeDetector(
          oarlockKey: key,
          settings: settings,
          onEvent: _onEvent,
          onCycle: _onCycle,
        ),
      );
    });

    // An oarlock that disconnected mid-stroke is no longer worth waiting for.
    if (_pending.isNotEmpty && _bindings.keys.every(_pending.containsKey)) {
      _closeCrewStroke();
    }
  }

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

  void _onEvent(StrokeEvent event) {
    _events.add(event);
    if (event.type == StrokeEventType.catch_) session?.onRowingDetected();
    if (event.type == StrokeEventType.finish) session?.onStrokeActivity();
  }

  void _onCycle(OarlockCycle cycle) {
    _pending[cycle.oarlockKey] = cycle;
    if (_bindings.keys.every(_pending.containsKey)) {
      _closeCrewStroke();
      return;
    }
    _quorumTimer ??= Timer(quorumWindow, _closeCrewStroke);
  }

  /// Publishes with whoever reported. Called either because the whole crew is
  /// in, or because the quorum window closed on a silent oarlock.
  void _closeCrewStroke() {
    _quorumTimer?.cancel();
    _quorumTimer = null;
    if (_pending.isEmpty) return;

    final cycles = _pending.values.toList();
    _pending.clear();
    _emitCrewStroke(cycles, expected: _bindings.length);
  }

  void _emitCrewStroke(List<OarlockCycle> cycles, {required int expected}) {
    final finishes = cycles.map((c) => c.finishTime).toList();
    final crewFinish = settings.crewAggregation == CrewAggregation.max
        ? finishes.reduce((a, b) => a.isAfter(b) ? a : b)
        : _meanTime(finishes);

    final crew = CrewStroke(
      finishTime: crewFinish,
      finishSpread: _spread(finishes),
      stroke: _meanDuration(cycles.map((c) => c.stroke)),
      drive: _meanDuration(cycles.map((c) => c.drive)),
      recovery: _meanDuration(cycles.map((c) => c.recovery)),
      reversalToCatch: _meanDuration(cycles.map((c) => c.reversalToCatch)),
      catchAngle: _mean(cycles.map((c) => c.catchAngle)),
      finishAngle: _mean(cycles.map((c) => c.finishAngle)),
      contributors: cycles.length,
      expected: expected == 0 ? cycles.length : expected,
    );
    _publish(crew);
  }

  /// Synchronisation is a property of a crew: one oarlock has none to report.
  Duration? _spread(List<DateTime> finishes) {
    if (finishes.length < 2) return null;
    final latest = finishes.reduce((a, b) => a.isAfter(b) ? a : b);
    final earliest = finishes.reduce((a, b) => a.isBefore(b) ? a : b);
    return latest.difference(earliest);
  }

  void _publish(CrewStroke crew) {
    final t = crew.finishTime;
    _strokeCount++;
    _count.add(Measurement(value: _strokeCount.toDouble(), timestamp: t));
    _rate.add(Measurement(value: crew.strokesPerMinute, timestamp: t));
    _ratio.add(Measurement(value: crew.driveRecoveryRatio, timestamp: t));
    _reversalToCatch.add(
      Measurement(
        value: crew.reversalToCatch.inMicroseconds / 1e6,
        timestamp: t,
      ),
    );
    _catchAngle.add(Measurement(value: crew.catchAngle, timestamp: t));
    _finishAngle.add(Measurement(value: crew.finishAngle, timestamp: t));
    _sweep.add(Measurement(value: crew.sweep, timestamp: t));
    _reporting.add(
      Measurement(value: crew.contributors.toDouble(), timestamp: t),
    );
    final spread = crew.finishSpread;
    if (spread != null) {
      _crewSync.add(
        Measurement(value: spread.inMicroseconds / 1e6, timestamp: t),
      );
    }
    _publishDistance(t);
  }

  void _publishDistance(DateTime t) {
    final total = session?.distanceMeters;
    if (total == null) return;
    final previous = _lastDistanceSnapshot;
    _lastDistanceSnapshot = total;
    if (previous != null) {
      _distance.add(Measurement(value: total - previous, timestamp: t));
    }
  }

  double _mean(Iterable<double> values) =>
      values.reduce((a, b) => a + b) / values.length;

  Duration _meanDuration(Iterable<Duration> values) => Duration(
    microseconds:
        (values.map((d) => d.inMicroseconds).reduce((a, b) => a + b) /
                values.length)
            .round(),
  );

  DateTime _meanTime(List<DateTime> times) =>
      DateTime.fromMicrosecondsSinceEpoch(
        (times.map((t) => t.microsecondsSinceEpoch).reduce((a, b) => a + b) /
                times.length)
            .round(),
      );

  PushDataSource _register(String name, Unit unit) {
    final source = PushDataSource(
      name: name,
      unit: unit,
      group: 'Stroke',
      idleHint: 'No strokes detected yet — one value per stroke.',
    );
    registry.registerDeferred(source);
    return source;
  }

  void dispose() {
    _disposed = true;
    _quorumTimer?.cancel();
    _quorumTimer = null;
    session?.removeListener(_onSession);
    registry.removeListener(_schedule);
    settings.removeListener(_schedule);
    for (final binding in _bindings.values) {
      binding.dispose();
    }
    _bindings.clear();
    for (final source in [
      _rate,
      _count,
      _ratio,
      _reversalToCatch,
      _distance,
      _catchAngle,
      _finishAngle,
      _sweep,
      _crewSync,
      _reporting,
    ]) {
      registry.unregister(source.name);
      source.dispose();
    }
    _events.close();
  }
}

class _SourcePair {
  final DataSource force;
  final DataSource angle;
  _SourcePair(this.force, this.angle);
}

/// Fuses an oarlock's identically-timestamped `Force`/`Angle` samples into the
/// detector.
class _OarlockBinding {
  final DataSource force;
  final DataSource angle;
  final OarlockStrokeDetector detector;
  final bool Function() isPaused;

  late final StreamSubscription<Measurement> _forceSub;
  late final StreamSubscription<Measurement> _angleSub;
  Measurement? _pendingForce;
  Measurement? _pendingAngle;

  _OarlockBinding({
    required this.force,
    required this.angle,
    required this.detector,
    required this.isPaused,
  }) {
    _forceSub = force.data.listen((m) {
      _pendingForce = m;
      _tryFuse();
    });
    _angleSub = angle.data.listen((m) {
      _pendingAngle = m;
      _tryFuse();
    });
  }

  bool matches(DataSource force, DataSource angle) =>
      identical(this.force, force) && identical(this.angle, angle);

  void _tryFuse() {
    final f = _pendingForce;
    final a = _pendingAngle;
    if (f == null || a == null) return;
    if (f.timestamp == a.timestamp) {
      // Fusion keeps running while paused so alignment survives the gap; only
      // the segmentation is suspended.
      if (!isPaused()) detector.add(a.value, f.value, f.timestamp);
      _pendingForce = null;
      _pendingAngle = null;
    } else if (f.timestamp.isBefore(a.timestamp)) {
      _pendingForce = null;
    } else {
      _pendingAngle = null;
    }
  }

  void dispose() {
    _forceSub.cancel();
    _angleSub.cancel();
  }
}
