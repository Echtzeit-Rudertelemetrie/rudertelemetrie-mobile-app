import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';

/// Persists the per-oarlock rig map for [BoatConfig].
abstract class RigConfigStore {
  Future<Map<String, RigConfig>> load();
  Future<void> save(Map<String, RigConfig> rigs);
}

/// File-backed [RigConfigStore] writing `rig_config.json` in the app documents
/// directory.
class FileRigConfigStore implements RigConfigStore {
  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/rig_config.json');
  }

  @override
  Future<Map<String, RigConfig>> load() async {
    final file = await _file();
    if (!await file.exists()) return {};
    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key.toString():
              RigConfig.fromJson((entry.value as Map).cast<String, dynamic>()),
    };
  }

  @override
  Future<void> save(Map<String, RigConfig> rigs) async {
    final json = jsonEncode({
      for (final entry in rigs.entries) entry.key: entry.value.toJson(),
    });
    await (await _file()).writeAsString(json);
  }
}
