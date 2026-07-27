import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';

/// How a session was started/stopped: by the user or by detection.
enum StartMode { manual, auto }

/// Lightweight identity + timing of one recording, shared between the live
/// [RecordingSession] and the persistence layer.
class SessionInfo {
  final String id;
  final DateTime startedAt;
  final StartMode startMode;

  const SessionInfo({
    required this.id,
    required this.startedAt,
    required this.startMode,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'startMode': startMode.name,
  };

  static SessionInfo? tryFromJson(Map<String, dynamic> json) {
    try {
      return SessionInfo(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        startMode: StartMode.values.byName(json['startMode'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// Reconstructs the identity of a session from its directory name
  /// (`session_<millisSinceEpoch>`), for recovering one whose metadata is gone.
  static SessionInfo? fromDirectoryName(String name) {
    final millis = int.tryParse(name.replaceFirst('session_', ''));
    if (!name.startsWith('session_') || millis == null) return null;
    return SessionInfo(
      id: name,
      startedAt: DateTime.fromMillisecondsSinceEpoch(millis),
      startMode: StartMode.manual,
    );
  }
}

/// End-of-session summary written to `session.json` (metadata + reductions).
class SessionSummary {
  final SessionInfo info;
  final DateTime stoppedAt;
  final double distanceMeters;
  final Map<String, double> averages;
  final Map<String, double> peaks;

  /// What each oarlock's force was scaled by while this session was recorded,
  /// keyed by oarlock key.
  ///
  /// The transform is affine, so these constants make the recorded newtons
  /// losslessly re-interpretable if a calibration is later found to be wrong —
  /// which is why no raw count series is stored alongside them.
  final Map<String, ForceCalibration> forceCalibrations;

  /// The live zero offset removed from each oarlock, sampled once per second
  /// from [SessionInfo.startedAt]. Bounded to a few N/s, so 1 Hz is enough to
  /// reconstruct it; it is the only time-varying part of the transform above.
  final Map<String, List<double>> zeroTrace;

  const SessionSummary({
    required this.info,
    required this.stoppedAt,
    required this.distanceMeters,
    this.averages = const {},
    this.peaks = const {},
    this.forceCalibrations = const {},
    this.zeroTrace = const {},
  });

  Duration get duration => stoppedAt.difference(info.startedAt);

  /// Whether any oarlock was still on the nominal firmware scale. Those
  /// readings are proportional to force, not newtons, and the history screen
  /// says so rather than presenting them as measurements.
  bool get isProvisional =>
      forceCalibrations.isEmpty ||
      forceCalibrations.values.any((c) => !c.isCalibrated);

  Map<String, dynamic> toJson() => {
    'id': info.id,
    'startedAt': info.startedAt.toIso8601String(),
    'stoppedAt': stoppedAt.toIso8601String(),
    'startMode': info.startMode.name,
    'durationMs': duration.inMilliseconds,
    'distanceMeters': distanceMeters,
    'averages': averages,
    'peaks': peaks,
    'forceCalibrations': {
      for (final e in forceCalibrations.entries) e.key: e.value.toJson(),
    },
    'zeroTrace': zeroTrace,
  };

  /// Decodes one index entry, or null if it is malformed — one bad entry must
  /// not take down the whole session list.
  static SessionSummary? tryFromJson(Map<String, dynamic> json) {
    try {
      return SessionSummary(
        info: SessionInfo(
          id: json['id'] as String,
          startedAt: DateTime.parse(json['startedAt'] as String),
          startMode: StartMode.values.byName(json['startMode'] as String),
        ),
        stoppedAt: DateTime.parse(json['stoppedAt'] as String),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        averages: _numMap(json['averages']),
        peaks: _numMap(json['peaks']),
        forceCalibrations: _calibrationMap(json['forceCalibrations']),
        zeroTrace: _traceMap(json['zeroTrace']),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, double> _numMap(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is num)
          entry.key.toString(): (entry.value as num).toDouble(),
    };
  }

  /// Absent on sessions recorded before calibration existed; they read as
  /// provisional, which is exactly what they are.
  static Map<String, ForceCalibration> _calibrationMap(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key.toString(): ForceCalibration.fromJson(
            (entry.value as Map).cast<String, dynamic>(),
          ),
    };
  }

  static Map<String, List<double>> _traceMap(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is List)
          entry.key.toString(): [
            for (final value in entry.value as List)
              if (value is num) value.toDouble(),
          ],
    };
  }
}
