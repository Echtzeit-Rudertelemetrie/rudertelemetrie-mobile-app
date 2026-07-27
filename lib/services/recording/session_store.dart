import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_record.dart';

/// Persists a session's time series and summary. A session's samples are
/// appended to `session.csv` in long format (`elapsed_ms,source,value`) while
/// recording, so the full series is never held in memory; `session.json` holds
/// the metadata/summary written on stop.
abstract class SessionStore {
  Future<void> beginSession(SessionInfo info);
  Future<void> finishSession(SessionSummary summary);
  Future<void> abortSession();
  Future<List<SessionSummary>> listSessions();
  Future<void> deleteSession(String id);

  /// Pushes buffered samples to disk, so an app kill loses at most a moment.
  Future<void> flush();

  /// Indexes session directories left behind by an interrupted recording, and
  /// discards the ones with no usable data. Returns what was recovered.
  Future<List<SessionSummary>> recoverOrphans();

  /// File paths (csv + json) for the share sheet, existing ones only.
  Future<List<String>> exportPaths(String id);

  /// Raw `session.csv` contents, or null if absent.
  Future<String?> readCsv(String id);
}

/// One decoded time-series sample from `session.csv`.
class SessionSample {
  final int elapsedMs;
  final double value;
  const SessionSample(this.elapsedMs, this.value);
}

/// Formats one long-format CSV row for a sample. Exposed for tests.
String sessionCsvRow(int elapsedMs, String source, double value) =>
    '$elapsedMs,${_escape(source)},$value';

/// Parses a long-format `session.csv` into per-source sample series. Tolerant of
/// the header row and quoted source names. Exposed for tests and replay.
Map<String, List<SessionSample>> parseSessionCsv(String csv) {
  final series = <String, List<SessionSample>>{};
  for (final line in const LineSplitter().convert(csv)) {
    if (line.isEmpty || line.startsWith('elapsed_ms')) continue;
    final fields = _splitCsvRow(line);
    if (fields.length != 3) continue;
    final elapsed = int.tryParse(fields[0]);
    final value = double.tryParse(fields[2]);
    if (elapsed == null || value == null) continue;
    (series[fields[1]] ??= []).add(SessionSample(elapsed, value));
  }
  return series;
}

List<String> _splitCsvRow(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == ',' && !inQuotes) {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(ch);
    }
  }
  fields.add(buffer.toString());
  return fields;
}

String _escape(String field) => field.contains(',') || field.contains('"')
    ? '"${field.replaceAll('"', '""')}"'
    : field;

/// File-backed [SessionStore] rooted at the app documents directory. Subscribes
/// to the live [DataSourceRegistry] itself so every registered source is logged,
/// including ones that appear mid-session (e.g. an oarlock connecting).
class FileSessionStore implements SessionStore {
  static const _csvHeader = 'elapsed_ms,source,value';
  static const _flushInterval = Duration(seconds: 5);

  final DataSourceRegistry registry;

  IOSink? _csvSink;
  SessionInfo? _active;
  String? _finishedId;
  Timer? _flushTimer;
  final Map<String, StreamSubscription<Measurement>> _subs = {};
  Future<void> _queue = Future.value();

  FileSessionStore(this.registry);

  /// Runs [op] after every previously queued store mutation has settled, so
  /// begin/finish/abort can never interleave on the same directory.
  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Directory> _sessionsRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/sessions');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _sessionDir(String id) async {
    final dir = Directory('${(await _sessionsRoot()).path}/$id');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<void> beginSession(SessionInfo info) => _serial(() => _begin(info));

  Future<void> _begin(SessionInfo info) async {
    await _abort();
    _active = info;
    if (_finishedId == info.id) _finishedId = null;

    final dir = await _sessionDir(info.id);
    // Written up front so a session interrupted before `finishSession` is still
    // self-describing when the next launch sweeps for orphans.
    await File(
      '${dir.path}/session.json',
    ).writeAsString(jsonEncode(info.toJson()));
    final sink = File('${dir.path}/session.csv').openWrite()
      ..writeln(_csvHeader);
    _csvSink = sink;

    _flushTimer = Timer.periodic(_flushInterval, (_) => unawaited(flush()));
    registry.addListener(_syncSubscriptions);
    _syncSubscriptions();
  }

  @override
  Future<void> flush() async {
    try {
      await _csvSink?.flush();
    } catch (_) {
      // A failed flush is retried by the next tick or by close().
    }
  }

  void _syncSubscriptions() {
    for (final source in registry.all) {
      _subs.putIfAbsent(
        source.name,
        () => source.data.listen(_logSample(source)),
      );
    }
  }

  void Function(Measurement) _logSample(DataSource source) {
    return (measurement) {
      final info = _active;
      final sink = _csvSink;
      if (info == null || sink == null) return;
      final elapsedMs = measurement.timestamp
          .difference(info.startedAt)
          .inMilliseconds;
      sink.writeln(sessionCsvRow(elapsedMs, source.name, measurement.value));
    };
  }

  Future<void> _teardownSubscriptions() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    registry.removeListener(_syncSubscriptions);
    for (final sub in _subs.values) {
      await sub.cancel();
    }
    _subs.clear();
    await _csvSink?.flush();
    await _csvSink?.close();
    _csvSink = null;
  }

  @override
  Future<void> finishSession(SessionSummary summary) =>
      _serial(() => _finish(summary));

  Future<void> _finish(SessionSummary summary) async {
    if (_active == null) return;
    await _teardownSubscriptions();
    final dir = await _sessionDir(summary.info.id);
    final json = const JsonEncoder.withIndent('  ').convert(summary.toJson());
    await File('${dir.path}/session.json').writeAsString(json);
    await _appendToIndex(summary);
    _finishedId = summary.info.id;
    _active = null;
  }

  @override
  Future<void> abortSession() => _serial(_abort);

  /// Discards the in-flight session. A session that already reached
  /// [finishSession] is kept — a late reset must not delete saved data.
  Future<void> _abort() async {
    final info = _active;
    if (info == null || info.id == _finishedId) return;
    await _teardownSubscriptions();
    final dir = await _sessionDir(info.id);
    if (await dir.exists()) await dir.delete(recursive: true);
    _active = null;
  }

  Future<File> _indexFile() async =>
      File('${(await _sessionsRoot()).path}/index.json');

  Future<void> _appendToIndex(SessionSummary summary) async {
    final entries =
        (await _list()).where((s) => s.info.id != summary.info.id).toList()
          ..add(summary);
    entries.sort((a, b) => b.info.startedAt.compareTo(a.info.startedAt));
    await _writeIndex(entries);
  }

  Future<void> _writeIndex(List<SessionSummary> entries) async {
    final json = jsonEncode(entries.map((s) => s.toJson()).toList());
    await (await _indexFile()).writeAsString(json);
  }

  @override
  Future<List<SessionSummary>> listSessions() => _serial(_list);

  /// Reads the index, skipping entries that fail to parse. An index that cannot
  /// be decoded at all is moved aside so History opens empty instead of failing.
  Future<List<SessionSummary>> _list() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) throw const FormatException('index is not a list');
      return [
        for (final entry in raw)
          if (entry is Map<String, dynamic>) ?SessionSummary.tryFromJson(entry),
      ];
    } catch (_) {
      await _quarantine(file);
      return [];
    }
  }

  Future<void> _quarantine(File file) async {
    try {
      await file.rename('${file.path}.corrupt');
    } catch (_) {
      // Losing the broken copy is acceptable; not starting up is not.
    }
  }

  @override
  Future<List<SessionSummary>> recoverOrphans() => _serial(_recoverOrphans);

  /// A recording killed mid-outing leaves a directory that nothing lists and
  /// nothing deletes. Everything on disk but absent from the index is either
  /// rebuilt from its CSV — it is the user's training — or discarded when there
  /// is nothing in it.
  Future<List<SessionSummary>> _recoverOrphans() async {
    final indexed = (await _list()).toList();
    final known = indexed.map((s) => s.info.id).toSet();
    final recovered = <SessionSummary>[];

    for (final dir in await _sessionDirectories()) {
      final id = dir.path.split(Platform.pathSeparator).last;
      if (known.contains(id) || id == _active?.id) continue;

      final summary = await _rebuildSummary(dir, id);
      if (summary == null) {
        await _deleteQuietly(dir);
        continue;
      }
      recovered.add(summary);
    }

    if (recovered.isEmpty) return const [];
    final entries = [...indexed, ...recovered]
      ..sort((a, b) => b.info.startedAt.compareTo(a.info.startedAt));
    await _writeIndex(entries);
    return recovered;
  }

  Future<List<Directory>> _sessionDirectories() async {
    try {
      return (await _sessionsRoot()).listSync().whereType<Directory>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<SessionSummary?> _rebuildSummary(Directory dir, String id) async {
    final info = await _readInfo(dir) ?? SessionInfo.fromDirectoryName(id);
    if (info == null) return null;

    final csv = File('${dir.path}/session.csv');
    if (!await csv.exists()) return null;
    final series = parseSessionCsv(await csv.readAsString());
    if (series.isEmpty) return null;

    var lastMs = 0;
    for (final samples in series.values) {
      if (samples.isNotEmpty && samples.last.elapsedMs > lastMs) {
        lastMs = samples.last.elapsedMs;
      }
    }
    final distance = series['Distance'];
    return SessionSummary(
      info: info,
      stoppedAt: info.startedAt.add(Duration(milliseconds: lastMs)),
      distanceMeters: distance == null || distance.isEmpty
          ? 0
          : distance.last.value,
    );
  }

  Future<SessionInfo?> _readInfo(Directory dir) async {
    try {
      final file = File('${dir.path}/session.json');
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      return raw is Map<String, dynamic> ? SessionInfo.tryFromJson(raw) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteQuietly(Directory dir) async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {
      // An undeletable leftover is not worth failing startup over.
    }
  }

  @override
  Future<void> deleteSession(String id) => _serial(() => _delete(id));

  Future<void> _delete(String id) async {
    final dir = Directory('${(await _sessionsRoot()).path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
    await _writeIndex((await _list()).where((s) => s.info.id != id).toList());
  }

  @override
  Future<List<String>> exportPaths(String id) async {
    final dir = await _sessionDir(id);
    return [
      for (final name in ['session.csv', 'session.json'])
        if (await File('${dir.path}/$name').exists()) '${dir.path}/$name',
    ];
  }

  @override
  Future<String?> readCsv(String id) async {
    final file = File('${(await _sessionDir(id)).path}/session.csv');
    return await file.exists() ? file.readAsString() : null;
  }
}
