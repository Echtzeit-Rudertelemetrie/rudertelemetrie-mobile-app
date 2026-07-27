import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';

/// The reductions a value tile can apply to a base source.
enum Reduction { raw, average, peak }

/// Base for a [DataSource] that reduces another source over the current
/// recording session. Accumulation is re-based whenever the session (re)starts
/// and frozen once it stops (recording-session spec).
abstract class SessionReducerSource extends DataSource {
  final DataSource base;
  final RecordingSession session;

  final StreamController<Measurement> _controller =
      StreamController.broadcast();
  StreamSubscription<Measurement>? _sub;
  DateTime? _origin;

  SessionReducerSource(this.base, this.session) {
    _origin = session.startedAt;
    session.addListener(_onSession);
    _sub = base.data.listen(_onSample);
  }

  String get namePrefix;

  @override
  String get name => '$namePrefix ${base.name}';

  @override
  Unit get unit => base.unit;

  @override
  String? get group => base.group;

  @override
  DateTime get startTime => base.startTime;

  @override
  Stream<Measurement> get data => _controller.stream;

  void _onSession() {
    if (session.startedAt != _origin) {
      _origin = session.startedAt;
      resetState();
    }
  }

  void _onSample(Measurement m) {
    if (!session.isRecording) return;
    final out = reduce(m);
    if (out != null) {
      _controller.add(Measurement(value: out, timestamp: m.timestamp));
    }
  }

  /// Fold [m] into the running reduction, returning the value to emit (or null).
  double? reduce(Measurement m);

  void resetState();

  @override
  void dispose() {
    session.removeListener(_onSession);
    _sub?.cancel();
    _controller.close();
  }
}

/// Time-weighted mean of [base] since the session start (kinematics §5).
class RunningAverageSource extends SessionReducerSource {
  RunningAverageSource(super.base, super.session);

  double _weightedSum = 0;
  DateTime? _lastTime;
  double? _lastValue;

  @override
  String get namePrefix => 'Avg';

  @override
  double? reduce(Measurement m) {
    final start = session.startedAt;
    final last = _lastTime;
    if (last != null) {
      final dt = m.timestamp.difference(last).inMicroseconds / 1e6;
      _weightedSum += 0.5 * (m.value + (_lastValue ?? m.value)) * dt;
    }
    _lastTime = m.timestamp;
    _lastValue = m.value;

    if (start == null) return m.value;
    final elapsed = m.timestamp.difference(start).inMicroseconds / 1e6;
    return elapsed > 0 ? _weightedSum / elapsed : m.value;
  }

  @override
  void resetState() {
    _weightedSum = 0;
    _lastTime = null;
    _lastValue = null;
  }
}

/// Running maximum of [base] since the session start.
class SessionPeakSource extends SessionReducerSource {
  SessionPeakSource(super.base, super.session);

  double? _peak;

  @override
  String get namePrefix => 'Peak';

  @override
  double? reduce(Measurement m) {
    _peak = _peak == null ? m.value : (m.value > _peak! ? m.value : _peak);
    return _peak;
  }

  @override
  void resetState() => _peak = null;
}

/// Builds (or fetches) the registered reducer source for [base] under
/// [reduction], returning the base itself for [Reduction.raw].
DataSource? reducedSource(
  DataSource base,
  Reduction reduction,
  RecordingSession session,
) {
  return switch (reduction) {
    Reduction.raw => base,
    Reduction.average => RunningAverageSource(base, session),
    Reduction.peak => SessionPeakSource(base, session),
  };
}
