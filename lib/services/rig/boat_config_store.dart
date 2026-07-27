import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';

/// Serialisable snapshot of the whole boat configuration (rig + crew layout).
class BoatConfigData {
  final Map<String, RigConfig> rigs;
  final BoatClass boatClass;
  final Map<String, SeatSlot> slots;

  const BoatConfigData({
    required this.rigs,
    required this.boatClass,
    required this.slots,
  });
}

/// Persists the [BoatConfig] (Part A rig + Part B crew layout).
abstract class BoatConfigStore {
  Future<BoatConfigData?> load();
  Future<void> save(BoatConfigData data);
}

/// File-backed store writing `boat_config.json` in the app documents directory.
/// A corrupt or unreadable file is treated as "nothing saved" and moved aside —
/// a broken rig must never keep the app from starting.
class FileBoatConfigStore implements BoatConfigStore {
  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/boat_config.json');
  }

  @override
  Future<BoatConfigData?> load() async {
    File? file;
    try {
      file = await _file();
      if (!await file.exists()) return null;
      return _parse(jsonDecode(await file.readAsString()));
    } catch (_) {
      if (file != null) await _quarantine(file);
      return null;
    }
  }

  Future<void> _quarantine(File file) async {
    try {
      await file.rename('${file.path}.corrupt');
    } catch (_) {
      // Losing the broken copy is acceptable; not starting up is not.
    }
  }

  BoatConfigData? _parse(dynamic raw) {
    if (raw is! Map) return null;

    final rigsRaw = raw['rigs'];
    final slotsRaw = raw['slots'];
    return BoatConfigData(
      rigs: {
        if (rigsRaw is Map)
          for (final e in rigsRaw.entries)
            if (e.value is Map)
              e.key.toString(): RigConfig.fromJson(
                (e.value as Map).cast<String, dynamic>(),
              ),
      },
      boatClass:
          BoatClass.values.asNameMap()[raw['boatClass']] ?? BoatClass.double_,
      slots: {
        if (slotsRaw is Map)
          for (final e in slotsRaw.entries)
            if (e.value is Map)
              e.key.toString(): SeatSlot.fromJson(
                (e.value as Map).cast<String, dynamic>(),
              ),
      },
    );
  }

  @override
  Future<void> save(BoatConfigData data) async {
    try {
      final json = jsonEncode({
        'rigs': {for (final e in data.rigs.entries) e.key: e.value.toJson()},
        'boatClass': data.boatClass.name,
        'slots': {for (final e in data.slots.entries) e.key: e.value.toJson()},
      });
      await (await _file()).writeAsString(json);
    } catch (_) {
      // A failed write loses the last edit, not the app.
    }
  }
}
