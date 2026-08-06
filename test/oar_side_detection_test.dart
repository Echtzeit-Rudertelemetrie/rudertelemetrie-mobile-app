import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oar_side_detection.dart';

const _sampleMs = 10; // the rate the sender decimates to
const _driveMs = 600;
const _recoveryMs = 1400;
const _step = Duration(milliseconds: _sampleMs);

/// Somewhere to put one fused `(θ, F)` sample — either a bare detector or the
/// service standing in front of one.
typedef _Sink = void Function(double angleDeg, double force, DateTime time);

/// Idle: no force, no motion. Long runs of this are what the threshold's
/// median is made of.
DateTime _feedIdle(_Sink sink, DateTime from, Duration duration) {
  var time = from;
  final end = from.add(duration);
  while (time.isBefore(end)) {
    sink(0, 0, time);
    time = time.add(_step);
  }
  return time;
}

/// One stroke: a drive at [peakForce] over which the angle sweeps at
/// [rateDegPerSecond], then an unloaded recovery back to where it started.
DateTime _feedStroke(
  _Sink sink,
  DateTime from,
  double rateDegPerSecond, {
  double peakForce = 400,
}) {
  var time = from;
  var angle = 0.0;

  final driveEnd = from.add(const Duration(milliseconds: _driveMs));
  while (time.isBefore(driveEnd)) {
    angle += rateDegPerSecond * _sampleMs / 1000;
    sink(angle, peakForce, time);
    time = time.add(_step);
  }

  final recoveryEnd = time.add(const Duration(milliseconds: _recoveryMs));
  final recoveryStep = rateDegPerSecond * _sampleMs / 1000 * _driveMs / _recoveryMs;
  while (time.isBefore(recoveryEnd)) {
    angle -= recoveryStep;
    sink(angle, 0, time);
    time = time.add(_step);
  }
  return time;
}

DateTime _feedStrokes(
  _Sink sink,
  DateTime from,
  int count,
  double rateDegPerSecond,
) {
  var time = from;
  for (var i = 0; i < count; i++) {
    time = _feedStroke(sink, time, rateDegPerSecond);
  }
  return time;
}

void main() {
  final origin = DateTime(2026, 8, 6, 10);

  late OarSideDetector detector;
  late _Sink feed;

  setUp(() {
    detector = OarSideDetector();
    feed = detector.add;
  });

  /// Past the warm-up, with enough idle history for the median to sit at zero.
  DateTime warmUp() => _feedIdle(feed, origin, const Duration(seconds: 5));

  test('says nothing before it has seen any strokes', () {
    warmUp();
    expect(detector.estimate, isNull);
  });

  test('says nothing after fewer strokes than the vote needs', () {
    _feedStrokes(feed, warmUp(), OarSideDetector.minVotes - 1, -30);
    expect(detector.estimate, isNull);
  });

  /// Rower's left. Measured median −30.0 °/s over 7 hand-simulated strokes.
  test('reads a negative drive sweep as starboard', () {
    _feedStrokes(feed, warmUp(), 4, -30);

    final estimate = detector.estimate;
    expect(estimate, isNotNull);
    expect(estimate!.side, OarSide.starboard);
    expect(estimate.isUnanimous, isTrue);
    expect(estimate.medianRateDegPerSecond, closeTo(-30, 1));
  });

  /// Rower's right. Measured median +42.3 °/s over 14 hand-simulated strokes.
  test('reads a positive drive sweep as port', () {
    _feedStrokes(feed, warmUp(), 4, 42);

    expect(detector.estimate?.side, OarSide.port);
  });

  /// The weakest starboard stroke in the calibration set came out at −3.7 °/s,
  /// close enough to zero that one stroke could plausibly have gone the other
  /// way. The vote is what keeps a single odd stroke from renaming the side.
  test('a single contrary stroke does not flip a settled side', () {
    final time = _feedStrokes(feed, warmUp(), 4, -30);
    expect(detector.estimate?.side, OarSide.starboard);

    _feedStroke(feed, time, 20);

    expect(detector.estimate?.side, OarSide.starboard);
  });

  test('follows the majority once the recent strokes have turned over', () {
    final time = _feedStrokes(feed, warmUp(), 4, -30);
    expect(detector.estimate?.side, OarSide.starboard);

    _feedStrokes(feed, time, OarSideDetector.voteWindow, 40);

    expect(detector.estimate?.side, OarSide.port);
  });

  /// The threshold is `median + 0.5·(p90 − median)`, never a fraction of the
  /// maximum: one spike from a knock on the gate would otherwise sit above
  /// every real drive and the detector would find no strokes at all.
  test('an outlier force spike does not lift the threshold past the drives', () {
    var time = warmUp();
    feed(0, 20000, time);
    time = time.add(_step);

    _feedStrokes(feed, time, 4, -30);

    expect(detector.estimate?.side, OarSide.starboard);
  });

  /// A hard-force blip shorter than a drive is a knock, not a stroke.
  test('ignores a run above the threshold too short to be a drive', () {
    var time = _feedStrokes(feed, warmUp(), 3, -30);
    final before = detector.estimate;

    for (var i = 0; i < 10; i++) {
      feed(i * 5.0, 400, time);
      time = time.add(_step);
    }
    _feedIdle(feed, time, const Duration(seconds: 1));

    expect(detector.estimate, before);
    expect(detector.completedStrokes, 3);
  });

  test('a loaded stretch with no swing is not a vote', () {
    // A calibration weight hanging on the cell: plenty of force, no motion.
    var time = warmUp();
    final end = time.add(const Duration(seconds: 2));
    while (time.isBefore(end)) {
      feed(0, 400, time);
      time = time.add(_step);
    }
    _feedIdle(feed, time, const Duration(seconds: 1));

    expect(detector.completedStrokes, 0);
  });

  /// Angles arrive wrapped into (−180, 180]. A stroke crossing the seam must
  /// not read as a 360°-per-sample lurch in the wrong direction.
  test('a stroke across the plus/minus 180 degree seam keeps its sign', () {
    var time = warmUp();
    for (var i = 0; i < 4; i++) {
      var angle = 170.0;
      final driveEnd = time.add(const Duration(milliseconds: _driveMs));
      while (time.isBefore(driveEnd)) {
        angle += 30 * _sampleMs / 1000;
        feed(_wrap(angle), 400, time);
        time = time.add(_step);
      }
      time = _feedIdle(feed, time, const Duration(milliseconds: _recoveryMs));
    }

    final estimate = detector.estimate;
    expect(estimate?.side, OarSide.port);
    expect(estimate!.medianRateDegPerSecond, closeTo(30, 2));
  });

  /// A calibration pause, a dropout or a reconnect leaves a hole. The angle
  /// either side of it is not one continuous motion.
  test('a gap in the stream abandons the drive in progress', () {
    var time = warmUp();
    var angle = 0.0;
    for (var i = 0; i < 30; i++) {
      angle -= 0.3;
      feed(angle, 400, time);
      time = time.add(_step);
    }

    time = time.add(OarSideDetector.maxSampleGap * 2);
    _feedIdle(feed, time, const Duration(seconds: 1));

    expect(detector.completedStrokes, 0);
  });

  group('applying a detection to the boat config', () {
    late BoatConfig config;
    late OarSideDetection detection;
    late _Sink oarlock;

    setUp(() {
      config = BoatConfig();
      detection = OarSideDetection(config: config);
      oarlock = (angle, force, time) =>
          detection.add('Oarlock 1', angle, force, time);
    });

    DateTime strokes(int count, double rate) => _feedStrokes(
      oarlock,
      _feedIdle(oarlock, origin, const Duration(seconds: 5)),
      count,
      rate,
    );

    test('fills a side that was never chosen by hand', () {
      config.assignSlot(
        'Oarlock 1',
        const SeatSlot(
          seat: 2,
          side: OarSide.both,
          sideOrigin: SideOrigin.unset,
        ),
      );

      strokes(4, -30);

      final slot = config.slotFor('Oarlock 1')!;
      expect(slot.side, OarSide.starboard);
      expect(slot.sideOrigin, SideOrigin.detected);
      expect(slot.seat, 2, reason: 'the seat is not the detector to change');
    });

    test('never overwrites a side the user set', () {
      config.assignSlot(
        'Oarlock 1',
        const SeatSlot(
          seat: 2,
          side: OarSide.port,
          sideOrigin: SideOrigin.manual,
        ),
      );

      strokes(4, -30);

      expect(config.slotFor('Oarlock 1')!.side, OarSide.port);
      expect(detection.estimateFor('Oarlock 1')?.side, OarSide.starboard);
    });

    test('does not invent a seat for an unplaced oarlock', () {
      strokes(4, -30);

      expect(config.slotFor('Oarlock 1'), isNull);
      expect(detection.estimateFor('Oarlock 1')?.side, OarSide.starboard);
    });

    test('forgetting an oarlock drops its estimate', () {
      strokes(4, -30);
      expect(detection.estimateFor('Oarlock 1'), isNotNull);

      detection.forget('Oarlock 1');

      expect(detection.estimateFor('Oarlock 1'), isNull);
    });
  });

  group('config provenance', () {
    test('a slot with no stored origin loads as manual', () {
      final slot = SeatSlot.fromJson(const {'seat': 1, 'side': 'port'});
      expect(slot.sideOrigin, SideOrigin.manual);
    });

    test('the origin survives a round trip', () {
      const slot = SeatSlot(
        seat: 3,
        side: OarSide.starboard,
        sideOrigin: SideOrigin.detected,
      );
      expect(SeatSlot.fromJson(slot.toJson()), slot);
    });

    test('a detected side is replaced by a later detection', () {
      final config = BoatConfig()
        ..assignSlot(
          'a',
          const SeatSlot(
            seat: 1,
            side: OarSide.port,
            sideOrigin: SideOrigin.detected,
          ),
        );

      expect(config.applyDetectedSide('a', OarSide.starboard), isTrue);
      expect(config.slotFor('a')!.side, OarSide.starboard);
      expect(config.applyDetectedSide('a', OarSide.starboard), isFalse);
    });
  });
}

double _wrap(double angle) {
  final wrapped = (angle + 180) % 360;
  return (wrapped < 0 ? wrapped + 360 : wrapped) - 180;
}
