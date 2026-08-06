import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oar_side_detection.dart';

/// Replays the bench recordings the side detection was calibrated against.
///
/// The captures live in the firmware repo and are gitignored there (`*.csv`),
/// so this skips itself when they are not on disk — it is a check to run next
/// to the hardware, not a CI gate. The synthetic coverage in
/// `oar_side_detection_test.dart` is what runs everywhere.
///
/// Point [_logDirectory] somewhere else with:
///   flutter test --dart-define=ROWING_BOAT_LOGS=/path/to/rowing_boat/logs
/// The default assumes the firmware repo sits next to this one, which is how
/// the project is normally checked out.
///
/// Recorded 2026-08-06 by hand-simulating strokes with real load on the gate.
/// `force_raw` is the firmware's tared microvolts straight off the USB log, not
/// the BLE path, so it is unquantised — the detector only ever looks at the
/// *shape* of the force, so the scale does not matter to it.
const _logDirectory = String.fromEnvironment(
  'ROWING_BOAT_LOGS',
  defaultValue: '../rowing-boat/rowing_boat/logs',
);

/// Runs one capture through a detector and returns the settled reading.
OarSideDetector _replay(String path) {
  final detector = OarSideDetector();
  final origin = DateTime(2026, 8, 6);

  for (final line in File(path).readAsLinesSync().skip(1)) {
    final fields = line.split(',');
    if (fields.length < 3) continue;
    final seconds = double.parse(fields[0]);
    detector.add(
      double.parse(fields[1]),
      double.parse(fields[2]),
      origin.add(Duration(microseconds: (seconds * 1e6).round())),
    );
  }
  return detector;
}

void main() {
  final available =
      File('$_logDirectory/kraft_links.csv').existsSync() &&
      File('$_logDirectory/kraft_rechts.csv').existsSync();

  group(
    'bench captures',
    skip: available
        ? null
        : 'firmware captures not found under $_logDirectory — pass '
              '--dart-define=ROWING_BOAT_LOGS=<dir> to point at them',
    () {
      /// The rower sits backwards, so the left hand side is starboard.
      /// Reported median over the whole capture was −30.0 °/s.
      test('kraft_links reads as starboard', () {
        final detector = _replay('$_logDirectory/kraft_links.csv');
        final estimate = detector.estimate;

        expect(estimate, isNotNull);
        expect(estimate!.side, OarSide.starboard);
        expect(estimate.isUnanimous, isTrue);
        expect(estimate.medianRateDegPerSecond, lessThan(-10));
      });

      /// The rower's right. Reported median +42.3 °/s; the detector's own
      /// segmentation lands on +43.2 °/s over the strokes it accepts.
      test('kraft_rechts reads as port', () {
        final detector = _replay('$_logDirectory/kraft_rechts.csv');
        final estimate = detector.estimate;

        expect(estimate, isNotNull);
        expect(estimate!.side, OarSide.port);
        expect(estimate.isUnanimous, isTrue);
        expect(estimate.medianRateDegPerSecond, closeTo(43, 5));
      });
    },
  );
}
