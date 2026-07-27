import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_record.dart';

const _key = 'Oarlock 1 (EE01)';

final _calibrated = ForceCalibration.fit(
  zeroRaw: 1000,
  loadedRaw: 11000,
  massKg: 20,
  at: DateTime(2026, 7, 27),
)!;

SessionSummary _summary({
  Map<String, ForceCalibration> calibrations = const {},
  Map<String, List<double>> zeroTrace = const {},
}) => SessionSummary(
  info: SessionInfo(
    id: 'session_1',
    startedAt: DateTime(2026, 7, 27, 9),
    startMode: StartMode.manual,
  ),
  stoppedAt: DateTime(2026, 7, 27, 10),
  distanceMeters: 5000,
  forceCalibrations: calibrations,
  zeroTrace: zeroTrace,
);

/// Round-trips through real JSON, not just the maps, so an unencodable value
/// would be caught here rather than at the point of writing session.json.
SessionSummary _reencode(SessionSummary summary) => SessionSummary.tryFromJson(
  jsonDecode(jsonEncode(summary.toJson())) as Map<String, dynamic>,
)!;

void main() {
  group('provisional marking', () {
    test('a session with no calibration data at all is provisional', () {
      expect(_summary().isProvisional, isTrue);
    });

    test('an oarlock on the nominal scale makes it provisional', () {
      final summary = _summary(
        calibrations: {_key: ForceCalibration.uncalibrated},
      );

      expect(summary.isProvisional, isTrue);
    });

    test('one uncalibrated oarlock in a crew is enough', () {
      final summary = _summary(
        calibrations: {
          _key: _calibrated,
          'Oarlock 2 (EE01)': ForceCalibration.uncalibrated,
        },
      );

      expect(summary.isProvisional, isTrue);
    });

    test('a fully calibrated crew is not provisional', () {
      final summary = _summary(
        calibrations: {_key: _calibrated, 'Oarlock 2 (EE01)': _calibrated},
      );

      expect(summary.isProvisional, isFalse);
    });
  });

  group('serialisation', () {
    test('round-trips the calibration constants', () {
      final restored = _reencode(_summary(calibrations: {_key: _calibrated}));

      expect(restored.forceCalibrations[_key], _calibrated);
      expect(restored.isProvisional, isFalse);
    });

    test('round-trips the zero trace', () {
      final restored = _reencode(
        _summary(
          calibrations: {_key: _calibrated},
          zeroTrace: {
            _key: [0, 1.5, 3.25],
          },
        ),
      );

      expect(restored.zeroTrace[_key], [0, 1.5, 3.25]);
    });

    test('a session recorded before calibration existed still loads', () {
      final legacy = {
        'id': 'session_1',
        'startedAt': '2026-07-27T09:00:00.000',
        'stoppedAt': '2026-07-27T10:00:00.000',
        'startMode': 'manual',
        'durationMs': 3600000,
        'distanceMeters': 5000.0,
      };

      final restored = SessionSummary.tryFromJson(legacy)!;

      expect(restored.forceCalibrations, isEmpty);
      expect(restored.zeroTrace, isEmpty);
      expect(restored.isProvisional, isTrue);
    });
  });

  group('invertibility', () {
    test('the stored constants recover the raw count from a saved force', () {
      final restored = _reencode(_summary(calibrations: {_key: _calibrated}));
      final calibration = restored.forceCalibrations[_key]!;

      // What the session recorded, for a raw count of 7531 and a live zero of
      // 12 N at that moment.
      const raw = 7531;
      const zeroAtTheTime = 12.0;
      final recorded = calibration.newtons(raw) - zeroAtTheTime;

      final recoveredRaw =
          (recorded + zeroAtTheTime) / calibration.scale + calibration.zeroRaw;

      expect(recoveredRaw, closeTo(raw.toDouble(), 1e-6));
    });
  });
}
