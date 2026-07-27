import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';

/// Persists per-oarlock force calibrations, keyed by oarlock key.
abstract class ForceCalibrationStore {
  Future<Map<String, ForceCalibration>?> load();
  Future<void> save(Map<String, ForceCalibration> calibrations);
}

/// File-backed store writing `force_calibration.json` in the app documents
/// directory. Kept separate from `boat_config.json` so recalibrating a load cell
/// never rewrites rig geometry.
///
/// A corrupt or unreadable file is treated as "nothing saved" and moved aside —
/// falling back to the nominal scale is recoverable, refusing to start is not.
class FileForceCalibrationStore implements ForceCalibrationStore {
  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/force_calibration.json');
  }

  @override
  Future<Map<String, ForceCalibration>?> load() async {
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

  /// Entries that would divide by ~zero are dropped rather than loaded: an
  /// unusable span produces an infinite scale, and every force in the app with
  /// it.
  Map<String, ForceCalibration>? _parse(dynamic raw) {
    if (raw is! Map) return null;
    final entries = raw['calibrations'];
    if (entries is! Map) return {};

    final parsed = <String, ForceCalibration>{};
    for (final entry in entries.entries) {
      if (entry.value is! Map) continue;
      final calibration = ForceCalibration.fromJson(
        (entry.value as Map).cast<String, dynamic>(),
      );
      if (calibration.isUsable) parsed[entry.key.toString()] = calibration;
    }
    return parsed;
  }

  @override
  Future<void> save(Map<String, ForceCalibration> calibrations) async {
    try {
      final json = jsonEncode({
        'calibrations': {
          for (final e in calibrations.entries) e.key: e.value.toJson(),
        },
      });
      await (await _file()).writeAsString(json);
    } catch (_) {
      // A failed write loses the last calibration, not the app.
    }
  }
}
