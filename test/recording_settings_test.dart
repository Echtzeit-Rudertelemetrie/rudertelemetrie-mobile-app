import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_settings.dart';

class _MemoryStore implements RecordingSettingsStore {
  Map<String, dynamic>? saved;

  @override
  Future<Map<String, dynamic>?> load() async => saved;

  @override
  Future<void> save(Map<String, dynamic> data) async => saved = data;
}

void main() {
  group('RecordingSettings', () {
    test('persists and restores every field', () async {
      final store = _MemoryStore();
      RecordingSettings(store: store)
        ..setAutoStart(false)
        ..setAutoStopIdle(const Duration(seconds: 90))
        ..setMinimumDuration(const Duration(seconds: 45));

      final restored = RecordingSettings(store: store);
      await restored.load();

      expect(restored.autoStart, isFalse);
      expect(restored.autoStopIdle, const Duration(seconds: 90));
      expect(restored.minimumDuration, const Duration(seconds: 45));
    });

    test('clamps values to their allowed range', () {
      final settings = RecordingSettings()
        ..setAutoStopIdle(const Duration(seconds: 5))
        ..setMinimumDuration(const Duration(hours: 1));

      expect(
        settings.autoStopIdle.inSeconds,
        RecordingSettings.autoStopIdleRange.min,
      );
      expect(
        settings.minimumDuration.inSeconds,
        RecordingSettings.minimumDurationRange.max,
      );
    });

    test('a corrupt or partial payload falls back to the defaults', () async {
      final store = _MemoryStore()..saved = {'autoStopIdleSeconds': 'soon'};
      final settings = RecordingSettings(store: store);
      await settings.load();

      expect(settings.autoStart, isTrue);
      expect(settings.autoStopIdle, const Duration(seconds: 20));
    });
  });

  group('RecordingSession honours the settings', () {
    late DataSourceRegistry registry;

    RecordingSession sessionWith(RecordingSettings settings) {
      final session = RecordingSession(registry: registry, settings: settings);
      addTearDown(session.dispose);
      return session;
    }

    setUp(() => registry = DataSourceRegistry());

    test('auto-start off means detection never starts a session', () {
      final session = sessionWith(RecordingSettings()..setAutoStart(false));

      session.onRowingDetected();
      expect(session.isRecording, isFalse);
      expect(session.isAutoArmed, isFalse);

      session.start(); // the record button still works
      expect(session.isRecording, isTrue);
    });

    test('auto-start on reports itself as armed while idle', () {
      final session = sessionWith(RecordingSettings());
      expect(session.isAutoArmed, isTrue);

      session.start();
      expect(session.isAutoArmed, isFalse); // already recording
    });

    test('a manual stop disarms auto-start until reset', () {
      final session = sessionWith(
        RecordingSettings()..setMinimumDuration(Duration.zero),
      );

      session.start();
      session.stop();
      expect(session.isAutoArmed, isFalse);

      session.reset();
      expect(session.isAutoArmed, isTrue);
    });

    test('a session below the minimum duration is discarded, not saved', () {
      final session = sessionWith(
        RecordingSettings()..setMinimumDuration(const Duration(seconds: 30)),
      );

      session.start();
      session.stop();

      expect(session.state, SessionState.idle);
      expect(session.startedAt, isNull);
    });

    test('a session above the minimum duration is kept', () {
      final session = sessionWith(
        RecordingSettings()..setMinimumDuration(Duration.zero),
      );

      session.start();
      session.stop();

      expect(session.state, SessionState.stopped);
    });
  });
}
