import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_record.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

import 'support/temp_documents.dart';

Map<String, dynamic> _entry(String id) => SessionSummary(
  info: SessionInfo(
    id: id,
    startedAt: DateTime(2026, 7, 1, 8),
    startMode: StartMode.manual,
  ),
  stoppedAt: DateTime(2026, 7, 1, 9),
  distanceMeters: 1200,
).toJson();

void main() {
  late Directory docs;
  late FileSessionStore store;

  setUp(() {
    docs = useTempDocumentsDirectory();
    store = FileSessionStore(DataSourceRegistry());
  });

  File writeIndex(String contents) {
    final dir = Directory('${docs.path}/sessions')..createSync(recursive: true);
    return File('${dir.path}/index.json')..writeAsStringSync(contents);
  }

  test('a missing index reads as no sessions', () async {
    expect(await store.listSessions(), isEmpty);
  });

  test('a malformed index degrades to empty and is moved aside', () async {
    final file = writeIndex('[{"id": "session_1", "startedAt"');

    expect(await store.listSessions(), isEmpty);
    expect(file.existsSync(), isFalse);
    expect(File('${file.path}.corrupt').existsSync(), isTrue);
  });

  test('an index that is not a list degrades to empty', () async {
    writeIndex('{"sessions": []}');
    expect(await store.listSessions(), isEmpty);
  });

  test('one bad entry does not hide the good ones', () async {
    writeIndex(
      jsonEncode([
        _entry('session_1'),
        {'id': 'session_broken', 'startedAt': 'not-a-date'},
        _entry('session_2'),
      ]),
    );

    final sessions = await store.listSessions();
    expect(sessions.map((s) => s.info.id), ['session_1', 'session_2']);
  });

  test('a readable index survives an unreadable entry field', () async {
    writeIndex(
      jsonEncode([
        {..._entry('session_1'), 'distanceMeters': 'far'},
        _entry('session_2'),
      ]),
    );

    expect((await store.listSessions()).map((s) => s.info.id), ['session_2']);
  });

  group('orphan recovery', () {
    Directory writeOrphan(String id, {String? csv, bool withInfo = true}) {
      final dir = Directory('${docs.path}/sessions/$id')
        ..createSync(recursive: true);
      if (withInfo) {
        File('${dir.path}/session.json').writeAsStringSync(
          jsonEncode(
            SessionInfo(
              id: id,
              startedAt: DateTime(2026, 7, 1, 8),
              startMode: StartMode.auto,
            ).toJson(),
          ),
        );
      }
      if (csv != null) File('${dir.path}/session.csv').writeAsStringSync(csv);
      return dir;
    }

    const csv =
        'elapsed_ms,source,value\n'
        '0,Distance,0\n'
        '30000,Distance,412.5\n'
        '30000,Speed (km/h),13.7\n';

    test('indexes a directory the index never learned about', () async {
      writeOrphan('session_100', csv: csv);

      final recovered = await store.recoverOrphans();
      expect(recovered.single.info.id, 'session_100');
      expect(recovered.single.duration, const Duration(seconds: 30));
      expect(recovered.single.distanceMeters, 412.5);

      expect((await store.listSessions()).map((s) => s.info.id), [
        'session_100',
      ]);
    });

    test('keeps the start mode recorded at begin time', () async {
      writeOrphan('session_100', csv: csv);
      final recovered = await store.recoverOrphans();
      expect(recovered.single.info.startMode, StartMode.auto);
    });

    test('falls back to the directory name when metadata is gone', () async {
      final startedAt = DateTime(2026, 7, 1, 8);
      writeOrphan(
        'session_${startedAt.millisecondsSinceEpoch}',
        csv: csv,
        withInfo: false,
      );

      final recovered = await store.recoverOrphans();
      expect(recovered.single.info.startedAt, startedAt);
    });

    test('discards a directory with no usable samples', () async {
      final empty = writeOrphan('session_200');
      final headerOnly = writeOrphan(
        'session_201',
        csv: 'elapsed_ms,source,value\n',
      );

      expect(await store.recoverOrphans(), isEmpty);
      expect(empty.existsSync(), isFalse);
      expect(headerOnly.existsSync(), isFalse);
    });

    test('leaves already-indexed sessions alone', () async {
      writeIndex(jsonEncode([_entry('session_1')]));
      writeOrphan('session_1', csv: csv);

      expect(await store.recoverOrphans(), isEmpty);
      expect((await store.listSessions()).length, 1);
    });

    test('recovered sessions join the existing index, newest first', () async {
      writeIndex(jsonEncode([_entry('session_1')]));
      final later = DateTime(2026, 7, 2, 8);
      writeOrphan(
        'session_${later.millisecondsSinceEpoch}',
        csv: csv,
        withInfo: false,
      );

      await store.recoverOrphans();
      final listed = await store.listSessions();
      expect(listed.length, 2);
      expect(listed.first.info.startedAt, later);
    });
  });
}
