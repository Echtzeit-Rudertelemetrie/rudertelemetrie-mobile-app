import 'package:rudertelemetrie_mobile_app/services/stroke/angle_velocity.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_event.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_settings.dart';

enum _State { recovery, drive }

/// Per-oarlock hysteresis state machine over the fused `(θ, F)` stream
/// (stroke-detection §5). Emits intra-cycle events and one [OarlockCycle] per
/// closed stroke. Rejects spurious catches (drive shorter than `τ_min`) and
/// impossibly fast strokes (`T_stroke < τ_stroke_min`).
class OarlockStrokeDetector {
  final String oarlockKey;
  final StrokeSettings settings;
  final void Function(StrokeEvent event) onEvent;
  final void Function(OarlockCycle cycle) onCycle;

  final AngleDifferentiator _diff =
      AngleDifferentiator(StrokeSettings.angleLpfCutoffHz);

  _State _state = _State.recovery;
  DateTime? _previousFinish;
  DateTime? _catchTime;
  double _catchAngle = 0;
  double _finishAngle = 0;
  double _peakAngle = -180;
  DateTime? _peakAngleTime;
  double _recentPeakForce = 0;

  OarlockStrokeDetector({
    required this.oarlockKey,
    required this.settings,
    required this.onEvent,
    required this.onCycle,
  });

  double get _fOn => switch (settings.mode) {
        ThresholdMode.absolute => settings.fOn,
        ThresholdMode.autoScaled =>
          _recentPeakForce > 0 ? settings.kOn * _recentPeakForce : settings.fOn,
      };

  double get _fOff => switch (settings.mode) {
        ThresholdMode.absolute => settings.fOff,
        ThresholdMode.autoScaled =>
          _recentPeakForce > 0 ? settings.kOff * _recentPeakForce : settings.fOff,
      };

  void add(double angleDeg, double force, DateTime time) {
    _diff.add(angleDeg, time);
    switch (_state) {
      case _State.recovery:
        _onRecovery(angleDeg, force, time);
      case _State.drive:
        _onDrive(angleDeg, force, time);
    }
  }

  void _onRecovery(double angleDeg, double force, DateTime time) {
    if (angleDeg > _peakAngle) {
      _peakAngle = angleDeg;
      _peakAngleTime = time;
    }
    if (force > _fOn) {
      _catchTime = time;
      _catchAngle = _peakAngle;
      _finishAngle = angleDeg;
      _emit(StrokeEventType.reversal, _peakAngleTime ?? time);
      _emit(StrokeEventType.catch_, time);
      _state = _State.drive;
    }
  }

  void _onDrive(double angleDeg, double force, DateTime time) {
    if (angleDeg < _finishAngle) _finishAngle = angleDeg;
    if (force > _drivePeakForce) _drivePeakForce = force;

    if (force >= _fOff) return;

    final driveSeconds =
        time.difference(_catchTime!).inMicroseconds / 1e6;
    if (driveSeconds < settings.tauMinDrive) {
      _revertSpuriousCatch(angleDeg, time);
      return;
    }
    _closeCycle(time);
  }

  double _drivePeakForce = 0;

  void _revertSpuriousCatch(double angleDeg, DateTime time) {
    _state = _State.recovery;
    _peakAngle = angleDeg;
    _peakAngleTime = time;
    _drivePeakForce = 0;
  }

  void _closeCycle(DateTime finish) {
    _emit(StrokeEventType.finish, finish);
    _recentPeakForce = _recentPeakForce == 0
        ? _drivePeakForce
        : 0.7 * _recentPeakForce + 0.3 * _drivePeakForce;

    final previous = _previousFinish;
    if (previous != null) {
      final strokeSeconds =
          finish.difference(previous).inMicroseconds / 1e6;
      final withinRate = strokeSeconds >= settings.tauMinStroke &&
          strokeSeconds <= settings.idleTimeout;
      if (withinRate) {
        onCycle(OarlockCycle(
          oarlockKey: oarlockKey,
          catchTime: _catchTime!,
          finishTime: finish,
          previousFinishTime: previous,
          reversalTime: _peakAngleTime ?? _catchTime!,
          catchAngle: _catchAngle,
          finishAngle: _finishAngle,
        ));
      }
    }

    _previousFinish = finish;
    _state = _State.recovery;
    _peakAngle = -180;
    _peakAngleTime = null;
    _drivePeakForce = 0;
  }

  void _emit(StrokeEventType type, DateTime time) =>
      onEvent(StrokeEvent(type: type, oarlockKey: oarlockKey, time: time));

  void reset() {
    _diff.reset();
    _state = _State.recovery;
    _previousFinish = null;
    _catchTime = null;
    _peakAngle = -180;
    _peakAngleTime = null;
    _drivePeakForce = 0;
    _recentPeakForce = 0;
  }
}
