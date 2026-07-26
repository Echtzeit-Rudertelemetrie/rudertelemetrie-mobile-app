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
class FileBoatConfigStore implements BoatConfigStore {
  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/boat_config.json');
  }

  @override
  Future<BoatConfigData?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map) return null;

    final rigsRaw = raw['rigs'];
    final slotsRaw = raw['slots'];
    return BoatConfigData(
      rigs: {
        if (rigsRaw is Map)
          for (final e in rigsRaw.entries)
            if (e.value is Map)
              e.key.toString():
                  RigConfig.fromJson((e.value as Map).cast<String, dynamic>()),
      },
      boatClass: BoatClass.values.asNameMap()[raw['boatClass']] ??
          BoatClass.double_,
      slots: {
        if (slotsRaw is Map)
          for (final e in slotsRaw.entries)
            if (e.value is Map)
              e.key.toString():
                  SeatSlot.fromJson((e.value as Map).cast<String, dynamic>()),
      },
    );
  }

  @override
  Future<void> save(BoatConfigData data) async {
    final json = jsonEncode({
      'rigs': {for (final e in data.rigs.entries) e.key: e.value.toJson()},
      'boatClass': data.boatClass.name,
      'slots': {for (final e in data.slots.entries) e.key: e.value.toJson()},
    });
    await (await _file()).writeAsString(json);
  }
}
