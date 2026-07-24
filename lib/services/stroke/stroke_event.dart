/// Intra-cycle events (stroke-detection §2). Anrollen needs the boat IMU and is
/// not emitted while that stream is simulated.
enum StrokeEventType { catch_, finish, reversal }

/// A single detected event for one oarlock.
class StrokeEvent {
  final StrokeEventType type;
  final String oarlockKey;
  final DateTime time;

  const StrokeEvent({
    required this.type,
    required this.oarlockKey,
    required this.time,
  });
}

/// One closed stroke cycle for a single oarlock (stroke-detection §4).
class OarlockCycle {
  final String oarlockKey;
  final DateTime catchTime;
  final DateTime finishTime;
  final DateTime previousFinishTime;
  final DateTime reversalTime;
  final double catchAngle;
  final double finishAngle;

  const OarlockCycle({
    required this.oarlockKey,
    required this.catchTime,
    required this.finishTime,
    required this.previousFinishTime,
    required this.reversalTime,
    required this.catchAngle,
    required this.finishAngle,
  });

  Duration get stroke => finishTime.difference(previousFinishTime);
  Duration get drive => finishTime.difference(catchTime);
  Duration get recovery => catchTime.difference(previousFinishTime);
  Duration get reversalToCatch => catchTime.difference(reversalTime);
  double get sweep => catchAngle - finishAngle;
}

/// A crew-aggregated stroke closed once every connected oarlock has finished
/// (stroke-detection §3/§4).
class CrewStroke {
  final DateTime finishTime;

  /// Spread of oarlock finish times, `max − min` (Crew Sync).
  final Duration finishSpread;
  final Duration stroke;
  final Duration drive;
  final Duration recovery;
  final Duration reversalToCatch;
  final double catchAngle;
  final double finishAngle;

  const CrewStroke({
    required this.finishTime,
    required this.finishSpread,
    required this.stroke,
    required this.drive,
    required this.recovery,
    required this.reversalToCatch,
    required this.catchAngle,
    required this.finishAngle,
  });

  double get sweep => catchAngle - finishAngle;
  double get strokesPerMinute {
    final seconds = stroke.inMicroseconds / 1e6;
    return seconds > 0 ? 60 / seconds : 0;
  }

  double get driveRecoveryRatio {
    final driveSeconds = drive.inMicroseconds / 1e6;
    return driveSeconds > 0 ? recovery.inMicroseconds / drive.inMicroseconds : 0;
  }
}
