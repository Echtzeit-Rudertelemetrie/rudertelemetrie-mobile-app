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
}

/// End-of-session summary written to `session.json` (metadata + reductions).
class SessionSummary {
  final SessionInfo info;
  final DateTime stoppedAt;
  final double distanceMeters;
  final Map<String, double> averages;
  final Map<String, double> peaks;

  const SessionSummary({
    required this.info,
    required this.stoppedAt,
    required this.distanceMeters,
    this.averages = const {},
    this.peaks = const {},
  });

  Duration get duration => stoppedAt.difference(info.startedAt);

  Map<String, dynamic> toJson() => {
        'id': info.id,
        'startedAt': info.startedAt.toIso8601String(),
        'stoppedAt': stoppedAt.toIso8601String(),
        'startMode': info.startMode.name,
        'durationMs': duration.inMilliseconds,
        'distanceMeters': distanceMeters,
        'averages': averages,
        'peaks': peaks,
      };

  static SessionSummary fromJson(Map<String, dynamic> json) => SessionSummary(
        info: SessionInfo(
          id: json['id'] as String,
          startedAt: DateTime.parse(json['startedAt'] as String),
          startMode: StartMode.values.byName(json['startMode'] as String),
        ),
        stoppedAt: DateTime.parse(json['stoppedAt'] as String),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        averages: _numMap(json['averages']),
        peaks: _numMap(json['peaks']),
      );

  static Map<String, double> _numMap(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): (entry.value as num).toDouble(),
    };
  }
}
