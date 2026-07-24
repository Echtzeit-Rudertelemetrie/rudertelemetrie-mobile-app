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
}

/// Formats one long-format CSV row for a sample. Exposed for tests.
String sessionCsvRow(int elapsedMs, String source, double value) =>
    '$elapsedMs,${_escape(source)},$value';

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
}
