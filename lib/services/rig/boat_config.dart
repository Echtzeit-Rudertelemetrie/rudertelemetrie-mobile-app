import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config_store.dart';

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
  bool get isValid => innerLever > 0 && scullLength > 0 && outerLever > 0;

  Map<String, dynamic> toJson() => {
    'innerLever': innerLever,
    'scullLength': scullLength,
  };

  static RigConfig fromJson(Map<String, dynamic> json) => RigConfig(
    innerLever: (json['innerLever'] as num).toDouble(),
    scullLength: (json['scullLength'] as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is RigConfig &&
      other.innerLever == innerLever &&
      other.scullLength == scullLength;

  @override
  int get hashCode => Object.hash(innerLever, scullLength);
}

/// Boat classes (boat-rig-config Part B). `x` = sculling (two oars per seat),
/// otherwise sweep (one oar per seat).
enum BoatClass {
  single('1x', 1, true),
  double_('2x', 2, true),
  quad('4x', 4, true),
  pair('2-', 2, false),
  four('4-', 4, false),
  eight('8+', 8, false);

  final String label;
  final int seats;
  final bool isSculling;
  const BoatClass(this.label, this.seats, this.isSculling);
}

/// Which side an oar sits on. `both` is a sculler (one oar each side).
enum OarSide { port, starboard, both }

/// Where an oarlock sits in the crew: seat position (1 = bow, sternward) + side.
class SeatSlot {
  final int seat;
  final OarSide side;

  const SeatSlot({required this.seat, required this.side});

  Map<String, dynamic> toJson() => {'seat': seat, 'side': side.name};

  static SeatSlot fromJson(Map<String, dynamic> json) => SeatSlot(
    seat: (json['seat'] as num).toInt(),
    side: OarSide.values.asNameMap()[json['side']] ?? OarSide.both,
  );
}

/// Per-oarlock rig (Part A) and crew layout (Part B), keyed by the stable
/// oarlock identity (its source group, e.g. `Oarlock 1 (1A2B)`) so both follow
/// the physical oarlock across reconnects. Persisted via [BoatConfigStore].
class BoatConfig extends ChangeNotifier {
  /// PO example defaults used as field placeholders.
  static const defaultRig = RigConfig(innerLever: 0.88, scullLength: 2.88);

  final BoatConfigStore? store;
  final Map<String, RigConfig> _rigs = {};
  final Map<String, SeatSlot> _slots = {};
  BoatClass _boatClass = BoatClass.double_;

  BoatConfig({this.store});

  Iterable<String> get oarlockKeys => _rigs.keys;
  BoatClass get boatClass => _boatClass;
  Map<String, SeatSlot> get slots => Map.unmodifiable(_slots);

  RigConfig? rigFor(String oarlockKey) => _rigs[oarlockKey];
  SeatSlot? slotFor(String oarlockKey) => _slots[oarlockKey];

  Future<void> load() async {
    final data = await store?.load();
    if (data == null) return;
    _rigs
      ..clear()
      ..addAll(data.rigs);
    _slots
      ..clear()
      ..addAll(data.slots);
    _boatClass = data.boatClass;
    notifyListeners();
  }

  void setRig(String oarlockKey, RigConfig rig) {
    if (_rigs[oarlockKey] == rig) return;
    _rigs[oarlockKey] = rig;
    _persist();
    notifyListeners();
  }

  void removeRig(String oarlockKey) {
    if (_rigs.remove(oarlockKey) == null) return;
    _persist();
    notifyListeners();
  }

  void setBoatClass(BoatClass boatClass) {
    if (boatClass == _boatClass) return;
    _boatClass = boatClass;
    _persist();
    notifyListeners();
  }

  void assignSlot(String oarlockKey, SeatSlot slot) {
    _slots[oarlockKey] = slot;
    _persist();
    notifyListeners();
  }

  void clearSlot(String oarlockKey) {
    if (_slots.remove(oarlockKey) == null) return;
    _persist();
    notifyListeners();
  }

  /// Forgets an oarlock entirely — rig and seat. For a device that will not come
  /// back, so config does not accumulate for every oarlock ever seen.
  void removeOarlock(String oarlockKey) {
    final hadRig = _rigs.remove(oarlockKey) != null;
    final hadSlot = _slots.remove(oarlockKey) != null;
    if (!hadRig && !hadSlot) return;
    _persist();
    notifyListeners();
  }

  /// Oarlocks whose seat+side collides with another oarlock's. Two oars cannot
  /// share a pin, and [computeBoatLayout] trusts the slots — it would happily
  /// draw them on top of each other.
  Set<String> get conflictingSlotKeys {
    final entries = _slots.entries.toList();
    final conflicts = <String>{};
    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        if (!_overlaps(entries[i].value, entries[j].value)) continue;
        conflicts
          ..add(entries[i].key)
          ..add(entries[j].key);
      }
    }
    return conflicts;
  }

  /// `both` is a sculler holding an oar on each side, so it overlaps either one.
  static bool _overlaps(SeatSlot a, SeatSlot b) =>
      a.seat == b.seat &&
      (a.side == b.side || a.side == OarSide.both || b.side == OarSide.both);

  void _persist() => store?.save(
    BoatConfigData(
      rigs: Map.of(_rigs),
      boatClass: _boatClass,
      slots: Map.of(_slots),
    ),
  );
}
