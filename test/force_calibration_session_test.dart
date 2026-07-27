import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration_session.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibrations.dart';

const _key = 'Oarlock 1 (EE01)';
final _origin = DateTime(2026, 7, 27);

/// Long enough to cover a capture plus the microtasks around it.
const _captureElapse = Duration(seconds: 3);

/// Pushes raw counts through [ForceCalibrations] the way the ingest path does,
/// so the session's tap has something to capture.
class RawFeeder {
  final ForceCalibrations calibrations;
  Timer? _timer;
  int _tick = 0;

  RawFeeder(this.calibrations);

  void emit(int Function(int tick) value) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      calibrations.newtons(
        _key,
        value(_tick),
        _origin.add(Duration(milliseconds: _tick * 10)),
      );
      _tick++;
    });
  }

  void stop() => _timer?.cancel();
}

/// Runs [body] on a fake clock, so a two-second capture costs no wall time.
void onFakeClock(
  void Function(
    FakeAsync clock,
    ForceCalibrations calibrations,
    ForceCalibrationSession session,
    RawFeeder feeder,
  )
  body,
) {
  FakeAsync().run((clock) {
    final calibrations = ForceCalibrations();
    final session = ForceCalibrationSession(calibrations: calibrations);
    final feeder = RawFeeder(calibrations);

    body(clock, calibrations, session, feeder);

    feeder.stop();
    session.dispose();
    calibrations.dispose();
    clock.flushMicrotasks();
  });
}

void main() {
  test('starts idle and inactive', () {
    onFakeClock((clock, calibrations, session, feeder) {
      expect(session.step, CalibrationStep.idle);
      expect(session.isActive, isFalse);
    });
  });

  test('begin pauses zero tracking, so a hung weight is not read as drift', () {
    onFakeClock((clock, calibrations, session, feeder) {
      session.begin(_key);

      expect(session.step, CalibrationStep.zeroPrompt);
      expect(calibrations.isTrackingPaused, isTrue);
    });
  });

  test('cancel resumes tracking and clears the draft', () {
    onFakeClock((clock, calibrations, session, feeder) {
      session.begin(_key);
      session.setMass(20);
      session.cancel();

      expect(session.step, CalibrationStep.idle);
      expect(session.massKg, isNull);
      expect(calibrations.isTrackingPaused, isFalse);
    });
  });

  test('fits a calibration from two steady captures', () {
    onFakeClock((clock, calibrations, session, feeder) {
      session.begin(_key);

      feeder.emit((_) => 1000);
      session.captureZero();
      clock.elapse(_captureElapse);
      expect(session.step, CalibrationStep.weightPrompt);

      session.setMass(20);
      feeder.emit((_) => 11000);
      session.captureSpan();
      clock.elapse(_captureElapse);

      expect(session.step, CalibrationStep.review);
      final fitted = session.fitted!;
      expect(fitted.newtons(11000), closeTo(20 * standardGravity, 0.5));
      expect(fitted.newtons(1000), closeTo(0, 0.5));
    });
  });

  test('refuses an unsteady capture and stays on the same step', () {
    onFakeClock((clock, calibrations, session, feeder) {
      session.begin(_key);

      feeder.emit((tick) => tick.isEven ? 0 : 40000);
      session.captureZero();
      clock.elapse(_captureElapse);

      expect(session.step, CalibrationStep.zeroPrompt);
      expect(session.fault, contains('unsteady'));
      expect(session.zeroCapture, isNull);
    });
  });

  test('reports a silent oarlock rather than fitting to nothing', () {
    onFakeClock((clock, calibrations, session, feeder) {
      session.begin(_key);

      session.captureZero();
      clock.elapse(_captureElapse);

      expect(session.step, CalibrationStep.zeroPrompt);
      expect(session.fault, contains('connected'));
    });
  });

  test('rejects a span too small to divide by', () {
    onFakeClock((clock, calibrations, session, feeder) {
      session.begin(_key);

      feeder.emit((_) => 1000);
      session.captureZero();
      clock.elapse(_captureElapse);

      session.setMass(20);
      session.captureSpan();
      clock.elapse(_captureElapse);

      expect(session.step, CalibrationStep.weightPrompt);
      expect(session.fault, contains('heavier'));
    });
  });

  test('will not start while a capture is already running', () {
    onFakeClock((clock, calibrations, session, feeder) {
      session.begin(_key);
      expect(session.begin('Oarlock 2 (EE01)'), isFalse);
      expect(session.oarlockKey, _key);
    });
  });

  test('commit stores the calibration and resumes tracking', () {
    onFakeClock((clock, calibrations, session, feeder) {
      session.begin(_key);

      feeder.emit((_) => 1000);
      session.captureZero();
      clock.elapse(_captureElapse);

      session.setMass(20);
      feeder.emit((_) => 11000);
      session.captureSpan();
      clock.elapse(_captureElapse);

      final fitted = session.fitted;
      session.commit();

      expect(calibrations.calibrationFor(_key), fitted);
      expect(calibrations.calibrationFor(_key).isCalibrated, isTrue);
      expect(calibrations.isTrackingPaused, isFalse);
      expect(session.step, CalibrationStep.idle);
    });
  });

  test('flags a weight too light to extrapolate from', () {
    onFakeClock((clock, calibrations, session, feeder) {
      session.begin(_key);

      feeder.emit((_) => 1000);
      session.captureZero();
      clock.elapse(_captureElapse);

      session.setMass(2);
      feeder.emit((_) => 11000);
      session.captureSpan();
      clock.elapse(_captureElapse);

      expect(session.isUnderloaded, isTrue);
    });
  });
}
