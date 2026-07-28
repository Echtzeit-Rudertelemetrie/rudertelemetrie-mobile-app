import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/screen_orientation_lock.dart';
import 'package:rudertelemetrie_mobile_app/services/display/orientation_settings.dart';

/// In-memory stand-in for [FileOrientationSettingsStore].
class FakeOrientationStore implements OrientationSettingsStore {
  Map<String, dynamic>? data;

  @override
  Future<Map<String, dynamic>?> load() async => data;

  @override
  Future<void> save(Map<String, dynamic> data) async => this.data = data;
}

void main() {
  group('orientation settings', () {
    test('defaults to following the device', () {
      expect(OrientationSettings().lock, OrientationLock.auto);
    });

    test('a lock is written through to the store', () async {
      final store = FakeOrientationStore();
      final settings = OrientationSettings(store: store);

      settings.setLock(OrientationLock.landscape);

      expect(settings.lock, OrientationLock.landscape);
      expect(store.data, {'lock': 'landscape'});
    });

    test('the saved lock is restored on load', () async {
      final store = FakeOrientationStore()..data = {'lock': 'portrait'};
      final settings = OrientationSettings(store: store);

      await settings.load();

      expect(settings.lock, OrientationLock.portrait);
    });

    test('an unreadable lock leaves the default alone', () async {
      final store = FakeOrientationStore()..data = {'lock': 'sideways-ish'};
      final settings = OrientationSettings(store: store);

      await settings.load();

      expect(settings.lock, OrientationLock.auto);
    });

    test('setting the current lock again does not notify', () {
      final settings = OrientationSettings();
      var notifications = 0;
      settings.addListener(() => notifications++);

      settings.setLock(OrientationLock.auto);

      expect(notifications, 0);
    });

    test('landscape allows either way up', () {
      expect(OrientationLock.landscape.allowed, [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });
  });

  group('applying the lock', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemChrome.setPreferredOrientations') {
              calls.add(call);
            }
            return null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    Widget scope(OrientationSettings settings) => ChangeNotifierProvider.value(
      value: settings,
      child: const ScreenOrientationLock(child: SizedBox()),
    );

    testWidgets('a changed lock reaches the system', (tester) async {
      final settings = OrientationSettings();
      await tester.pumpWidget(scope(settings));

      settings.setLock(OrientationLock.landscape);
      await tester.pump();

      expect(calls.last.arguments, [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
    });

    testWidgets('a lock loaded after startup is still applied', (tester) async {
      final settings = OrientationSettings(
        store: FakeOrientationStore()..data = {'lock': 'portrait'},
      );
      await tester.pumpWidget(scope(settings));

      await settings.load();
      await tester.pump();

      expect(calls.last.arguments, ['DeviceOrientation.portraitUp']);
    });
  });
}
