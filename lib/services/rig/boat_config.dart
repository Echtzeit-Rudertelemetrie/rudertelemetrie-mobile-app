import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/rig_config_store.dart';

/// Rig geometry for one oarlock (force-power-model §1). All lengths in metres.
class RigConfig {
  /// Inner lever, pin → handle.
  final double innerLever;

  /// Effective scull length, `L = l_in + l_out`.
  final double scullLength;

  const RigConfig({required this.innerLever, required this.scullLength});

  /// Outer lever, pin → blade pressure point (`l_out = L − l_in`).
  double get outerLever => scullLength - innerLever;

  /// Whether the geometry is usable for the force model.
  bool get isValid =>
      innerLever > 0 && scullLength > 0 && outerLever > 0;

  Map<String, dynamic> toJson() =>
      {'innerLever': innerLever, 'scullLength': scullLength};

  static RigConfig fromJson(Map<String, dynamic> json) => RigConfig(
        innerLever: (json['innerLever'] as num).toDouble(),
        scullLength: (json['scullLength'] as num).toDouble(),
      );
}

/// Per-oarlock rig configuration (boat-rig-config Part A). Keyed by the stable
/// oarlock identity (its source group, e.g. `Oarlock 1 (1A2B)`), so constants
/// follow the physical oarlock across reconnects. Persisted via [RigConfigStore].
class BoatConfig extends ChangeNotifier {
  /// PO example defaults used as field placeholders.
  static const defaultRig = RigConfig(innerLever: 0.88, scullLength: 2.88);

  final RigConfigStore? store;
  final Map<String, RigConfig> _rigs = {};

  BoatConfig({this.store});

  Iterable<String> get oarlockKeys => _rigs.keys;

  RigConfig? rigFor(String oarlockKey) => _rigs[oarlockKey];

  Future<void> load() async {
    final loaded = await store?.load();
    if (loaded == null || loaded.isEmpty) return;
    _rigs
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  void setRig(String oarlockKey, RigConfig rig) {
    _rigs[oarlockKey] = rig;
    _persist();
    notifyListeners();
  }

  void removeRig(String oarlockKey) {
    if (_rigs.remove(oarlockKey) == null) return;
    _persist();
    notifyListeners();
  }

  void _persist() => store?.save(Map.of(_rigs));
}
