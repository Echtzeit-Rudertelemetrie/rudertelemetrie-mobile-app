import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/derived/session_reducer_sources.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_settings.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_record.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

import 'support/temp_documents.dart';

double _latDegForMeters(double meters) => meters / 111320.0;

RecordingSettings _instantSessions() =>
    RecordingSettings()..setMinimumDuration(Duration.zero);

void main() {
  late DataSourceRegistry registry;
  late RecordingSession session;
  late PushDataSource lat;
  late PushDataSource lon;

  setUp(() {
    registry = DataSourceRegistry();
    // The tests drive instant start/stop pairs; the production minimum
    // duration would discard every one of them.
    session = RecordingSession(
      registry: registry,
      settings: _instantSessions(),
    );
    lat = PushDataSource(name: 'Latitude', unit: Unit.deg, group: 'Boat');
    lon = PushDataSource(name: 'Longitude', unit: Unit.deg, group: 'Boat');
    registry.register(lat);
    registry.register(lon);
  });

  tearDown(() => session.dispose());

  void feedFix(double meters, DateTime time) {
    lat.add(Measurement(value: _latDegForMeters(meters), timestamp: time));
    lon.add(Measurement(value: 0, timestamp: time));
  }

  test('registers the derived session sources in the picker', () {
    final names = registry.all.map((s) => s.name).toSet();
    expect(
      names,
      containsAll(<String>[
        'Speed (km/h)',
        'Pace (/500m)',
        'Distance',
        'Elapsed',
      ]),
    );
  });

  test('lifecycle: idle -> recording -> stopped -> reset', () {
    expect(session.state, SessionState.idle);
    session.start();
    expect(session.state, SessionState.recording);
    expect(session.isRecording, isTrue);
    session.stop();
    expect(session.state, SessionState.stopped);
    session.reset();
    expect(session.state, SessionState.idle);
    expect(session.distanceMeters, 0);
  });

  test('derives km/h speed and accumulates distance from GPS fixes', () async {
    session.start();
    final speeds = <double>[];
    registry.get('Speed (km/h)')!.data.listen((m) => speeds.add(m.value));

    final t0 = DateTime.fromMillisecondsSinceEpoch(1000000);
    feedFix(0, t0);
    feedFix(5, t0.add(const Duration(seconds: 1)));
    await pumpEventQueue();

    expect(speeds.last, closeTo(18, 0.2)); // 5 m/s -> 18 km/h
    expect(session.distanceMeters, closeTo(5, 0.1));
  });

  test('reset clears accumulated distance', () async {
    session.start();
    final t0 = DateTime.fromMillisecondsSinceEpoch(1000000);
    feedFix(0, t0);
    feedFix(5, t0.add(const Duration(seconds: 1)));
    await pumpEventQueue();
    expect(session.distanceMeters, greaterThan(0));

    session.reset();
    expect(session.distanceMeters, 0);
  });

  group('auto start/stop', () {
    test('onRowingDetected auto-starts an idle session', () {
      session.onRowingDetected();
      expect(session.isRecording, isTrue);
      expect(session.startMode, StartMode.auto);
    });

    test('manual stop disarms auto-restart until reset re-arms', () {
      session.onRowingDetected();
      session.stop(); // manual
      session.onRowingDetected();
      expect(session.isRecording, isFalse); // stays stopped, auto disarmed

      session.reset();
      session.onRowingDetected();
      expect(session.isRecording, isTrue);
    });

    test('manual start is not overridden by rowing detection', () {
      session.start(); // manual
      session.onRowingDetected();
      expect(session.startMode, StartMode.manual);
    });
  });

  group('store lifecycle', () {
    late Directory docs;
    late FileSessionStore store;
    late RecordingSession recorded;

    Directory sessionDir(String id) => Directory('${docs.path}/sessions/$id');

    setUp(() {
      docs = useTempDocumentsDirectory();
      store = FileSessionStore(registry);
      recorded = RecordingSession(
        registry: registry,
        store: store,
        settings: _instantSessions(),
      );
    });

    tearDown(() => recorded.dispose());

    test('stop then reset keeps the finished session', () async {
      recorded.start();
      final id = 'session_${recorded.startedAt!.millisecondsSinceEpoch}';
      recorded.stop();
      recorded.reset();
      await store.listSessions();

      expect(File('${sessionDir(id).path}/session.csv').existsSync(), isTrue);
      expect(File('${sessionDir(id).path}/session.json').existsSync(), isTrue);
      expect((await store.listSessions()).map((s) => s.info.id), [id]);
    });

    test('stop then start produces two independent sessions', () async {
      recorded.start();
      final first = 'session_${recorded.startedAt!.millisecondsSinceEpoch}';
      recorded.stop();
      recorded.reset();

      await Future<void>.delayed(const Duration(milliseconds: 5));
      recorded.start();
      final second = 'session_${recorded.startedAt!.millisecondsSinceEpoch}';
      recorded.stop();

      expect((await store.listSessions()).map((s) => s.info.id).toSet(), {
        first,
        second,
      });
      for (final id in [first, second]) {
        expect(File('${sessionDir(id).path}/session.csv').existsSync(), isTrue);
      }
    });

    test('reset without stop discards the session', () async {
      recorded.start();
      final id = 'session_${recorded.startedAt!.millisecondsSinceEpoch}';
      recorded.reset();
      await store.listSessions();

      expect(sessionDir(id).existsSync(), isFalse);
      expect(await store.listSessions(), isEmpty);
    });
  });

  group('reducers', () {
    test('RunningAverageSource is time-weighted since session start', () async {
      session.start();
      final base = PushDataSource(name: 'X', unit: Unit.N);
      registry.register(base);
      final avg = RunningAverageSource(base, session);
      addTearDown(avg.dispose);

      final values = <double>[];
      avg.data.listen((m) => values.add(m.value));

      final t0 = session.startedAt!;
      base.add(Measurement(value: 10, timestamp: t0));
      base.add(
        Measurement(value: 20, timestamp: t0.add(const Duration(seconds: 1))),
      );
      base.add(
        Measurement(value: 30, timestamp: t0.add(const Duration(seconds: 2))),
      );
      await pumpEventQueue();

      expect(values.last, closeTo(20, 0.01));
    });

    test('SessionPeakSource holds the running maximum', () async {
      session.start();
      final base = PushDataSource(name: 'Y', unit: Unit.N);
      registry.register(base);
      final peak = SessionPeakSource(base, session);
      addTearDown(peak.dispose);

      final values = <double>[];
      peak.data.listen((m) => values.add(m.value));

      final t0 = session.startedAt!;
      base.add(Measurement(value: 5, timestamp: t0));
      base.add(
        Measurement(value: 30, timestamp: t0.add(const Duration(seconds: 1))),
      );
      base.add(
        Measurement(value: 12, timestamp: t0.add(const Duration(seconds: 2))),
      );
      await pumpEventQueue();

      expect(values.last, 30);
    });
  });
}
