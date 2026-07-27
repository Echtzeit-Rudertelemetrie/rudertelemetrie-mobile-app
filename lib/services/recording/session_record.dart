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
}
