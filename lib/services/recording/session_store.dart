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

String _escape(String field) =>
    field.contains(',') || field.contains('"')
        ? '"${field.replaceAll('"', '""')}"'
        : field;

/// File-backed [SessionStore] rooted at the app documents directory. Subscribes
/// to the live [DataSourceRegistry] itself so every registered source is logged,
/// including ones that appear mid-session (e.g. an oarlock connecting).
class FileSessionStore implements SessionStore {
  static const _csvHeader = 'elapsed_ms,source,value';

  final DataSourceRegistry registry;

  IOSink? _csvSink;
  SessionInfo? _active;
  final Map<String, StreamSubscription<Measurement>> _subs = {};

  FileSessionStore(this.registry);

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
  Future<void> beginSession(SessionInfo info) async {
    await abortSession();
    _active = info;
    final file = File('${(await _sessionDir(info.id)).path}/session.csv');
    final sink = file.openWrite()..writeln(_csvHeader);
    _csvSink = sink;

    registry.addListener(_syncSubscriptions);
    _syncSubscriptions();
  }

  void _syncSubscriptions() {
    for (final source in registry.all) {
      _subs.putIfAbsent(source.name, () => source.data.listen(_logSample(source)));
    }
  }

  void Function(Measurement) _logSample(DataSource source) {
    return (measurement) {
      final info = _active;
      final sink = _csvSink;
      if (info == null || sink == null) return;
      final elapsedMs = measurement.timestamp.difference(info.startedAt).inMilliseconds;
      sink.writeln(sessionCsvRow(elapsedMs, source.name, measurement.value));
    };
  }

  Future<void> _teardownSubscriptions() async {
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
  Future<void> finishSession(SessionSummary summary) async {
    if (_active == null) return;
    await _teardownSubscriptions();
    final dir = await _sessionDir(summary.info.id);
    final json = const JsonEncoder.withIndent('  ').convert(summary.toJson());
    await File('${dir.path}/session.json').writeAsString(json);
    await _appendToIndex(summary);
    _active = null;
  }

  @override
  Future<void> abortSession() async {
    final info = _active;
    if (info == null) return;
    await _teardownSubscriptions();
    final dir = await _sessionDir(info.id);
    if (await dir.exists()) await dir.delete(recursive: true);
    _active = null;
  }

  Future<File> _indexFile() async =>
      File('${(await _sessionsRoot()).path}/index.json');

  Future<void> _appendToIndex(SessionSummary summary) async {
    final entries = (await listSessions())
        .where((s) => s.info.id != summary.info.id)
        .toList()
      ..add(summary);
    entries.sort((a, b) => b.info.startedAt.compareTo(a.info.startedAt));
    final json = jsonEncode(entries.map((s) => s.toJson()).toList());
    await (await _indexFile()).writeAsString(json);
  }

  @override
  Future<List<SessionSummary>> listSessions() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];
    final raw = jsonDecode(await file.readAsString());
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SessionSummary.fromJson)
        .toList();
  }

  @override
  Future<void> deleteSession(String id) async {
    final dir = Directory('${(await _sessionsRoot()).path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
    final remaining =
        (await listSessions()).where((s) => s.info.id != id).toList();
    final json = jsonEncode(remaining.map((s) => s.toJson()).toList());
    await (await _indexFile()).writeAsString(json);
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
