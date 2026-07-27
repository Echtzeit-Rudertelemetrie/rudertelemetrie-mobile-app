import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persists the recording preferences across launches.
abstract class RecordingSettingsStore {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> data);
}

/// File-backed store writing `recording_settings.json` in the app documents
/// directory. A corrupt file is treated as "nothing saved" — settings must never
/// keep the app from starting.
class FileRecordingSettingsStore implements RecordingSettingsStore {
  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/recording_settings.json');
  }

  @override
  Future<Map<String, dynamic>?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      return raw is Map<String, dynamic> ? raw : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    try {
      await (await _file()).writeAsString(jsonEncode(data));
    } catch (_) {
      // A failed write loses the last edit, not the app.
    }
  }
}

/// When a recording starts and stops by itself.
///
/// Auto-start is convenient on the water and a nuisance on the rack: carrying
/// the boat or testing an oarlock produces a catch too. Each of these is
/// adjustable because no single default fits every crew.
class RecordingSettings extends ChangeNotifier {
  static const autoStopIdleRange = (min: 10, max: 120);
  static const minimumDurationRange = (min: 0, max: 300);

  final RecordingSettingsStore? store;

  bool _autoStart = true;
  Duration _autoStopIdle = const Duration(seconds: 20);
  Duration _minimumDuration = const Duration(seconds: 30);

  RecordingSettings({this.store});

  bool get autoStart => _autoStart;
  Duration get autoStopIdle => _autoStopIdle;

  /// Sessions shorter than this are discarded rather than saved, which removes
  /// most accidental recordings.
  Duration get minimumDuration => _minimumDuration;

  Future<void> load() async {
    final data = await store?.load();
    if (data == null) return;
    _autoStart = data['autoStart'] as bool? ?? _autoStart;
    _autoStopIdle = _durationOf(
      data['autoStopIdleSeconds'],
      _autoStopIdle,
      autoStopIdleRange,
    );
    _minimumDuration = _durationOf(
      data['minimumDurationSeconds'],
      _minimumDuration,
      minimumDurationRange,
    );
    notifyListeners();
  }

  void setAutoStart(bool value) {
    if (value == _autoStart) return;
    _autoStart = value;
    _commit();
  }

  void setAutoStopIdle(Duration value) {
    final clamped = _clamp(value, autoStopIdleRange);
    if (clamped == _autoStopIdle) return;
    _autoStopIdle = clamped;
    _commit();
  }

  void setMinimumDuration(Duration value) {
    final clamped = _clamp(value, minimumDurationRange);
    if (clamped == _minimumDuration) return;
    _minimumDuration = clamped;
    _commit();
  }

  void _commit() {
    store?.save({
      'autoStart': _autoStart,
      'autoStopIdleSeconds': _autoStopIdle.inSeconds,
      'minimumDurationSeconds': _minimumDuration.inSeconds,
    });
    notifyListeners();
  }

  static Duration _clamp(Duration value, ({int min, int max}) range) =>
      Duration(seconds: value.inSeconds.clamp(range.min, range.max));

  static Duration _durationOf(
    dynamic raw,
    Duration fallback,
    ({int min, int max}) range,
  ) => raw is num ? _clamp(Duration(seconds: raw.toInt()), range) : fallback;
}
