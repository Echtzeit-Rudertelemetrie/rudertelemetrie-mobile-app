import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Which way up the app is allowed to turn.
enum OrientationLock {
  auto,
  portrait,
  landscape;

  /// The orientations the OS may rotate to. Both landscape sides stay allowed
  /// so a phone clamped to the boat can face either way.
  List<DeviceOrientation> get allowed => switch (this) {
    OrientationLock.auto => DeviceOrientation.values,
    OrientationLock.portrait => const [DeviceOrientation.portraitUp],
    OrientationLock.landscape => const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
  };

  static OrientationLock? byName(String? name) {
    for (final lock in values) {
      if (lock.name == name) return lock;
    }
    return null;
  }
}

/// Persists the display preferences across launches.
abstract class OrientationSettingsStore {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> data);
}

/// File-backed store writing `display_settings.json` in the app documents
/// directory. A corrupt file is treated as "nothing saved" — a preference must
/// never keep the app from starting.
class FileOrientationSettingsStore implements OrientationSettingsStore {
  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/display_settings.json');
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

/// Whether the app follows the device's rotation, or stays where it is put.
///
/// A phone mounted in a boat gets knocked about, and a dashboard that flips
/// mid-piece is worse than one facing a way the crew did not choose — so the
/// rotation can be pinned.
class OrientationSettings extends ChangeNotifier {
  final OrientationSettingsStore? store;

  OrientationLock _lock = OrientationLock.auto;

  OrientationSettings({this.store});

  OrientationLock get lock => _lock;

  Future<void> load() async {
    final data = await store?.load();
    final saved = OrientationLock.byName(data?['lock'] as String?);
    if (saved == null) return;
    _lock = saved;
    notifyListeners();
  }

  void setLock(OrientationLock value) {
    if (value == _lock) return;
    _lock = value;
    store?.save({'lock': value.name});
    notifyListeners();
  }
}
