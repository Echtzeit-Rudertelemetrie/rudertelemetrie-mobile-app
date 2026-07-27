import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'dashboard_preset.dart';

/// Persists the user's dashboard presets across app launches.
abstract class DashboardPresetStore {
  Future<DashboardPresetData?> load();
  Future<void> save(DashboardPresetData data);
}

/// File-backed store writing `dashboard_presets.json` in the app documents
/// directory, alongside `boat_config.json`. A corrupt or unreadable file is
/// treated as "no presets yet" rather than propagating — a broken layout must
/// never keep the app from starting.
class FileDashboardPresetStore implements DashboardPresetStore {
  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/dashboard_presets.json');
  }

  @override
  Future<DashboardPresetData?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      return DashboardPresetData(
        presets: _presetsFromJson(raw['presets']),
        activeId: raw['activeId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  List<DashboardPreset> _presetsFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map<String, dynamic>) DashboardPreset.fromJson(entry),
    ];
  }

  @override
  Future<void> save(DashboardPresetData data) async {
    try {
      final json = jsonEncode({
        'presets': [for (final p in data.presets) p.toJson()],
        'activeId': data.activeId,
      });
      await (await _file()).writeAsString(json);
    } catch (_) {
      // A failed write loses the last edit, not the app.
    }
  }
}
