import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';

/// A resolved oar position for the schematic.
class OarPlacement {
  final String oarlockKey;
  final int seat; // 1 = bow
  final OarSide side;

  const OarPlacement({
    required this.oarlockKey,
    required this.seat,
    required this.side,
  });
}

/// Resolves where each connected oarlock draws on the boat schematic. Uses the
/// assigned [BoatConfig] slot when present; otherwise falls back to a generic
/// bow-first layout (sequential seats, both oars for scull / alternating sides
/// for sweep) so the schematic still renders without a full crew setup.
List<OarPlacement> computeBoatLayout({
  required BoatClass boatClass,
  required Map<String, SeatSlot> slots,
  required List<String> oarlockKeys,
}) {
  final keys = [...oarlockKeys]..sort();
  final placements = <OarPlacement>[];
  var genericSeat = 1;
  for (final key in keys) {
    final slot = slots[key];
    if (slot != null) {
      placements.add(OarPlacement(oarlockKey: key, seat: slot.seat, side: slot.side));
      continue;
    }
    final side = boatClass.isSculling
        ? OarSide.both
        : (genericSeat.isOdd ? OarSide.starboard : OarSide.port);
    placements.add(OarPlacement(
      oarlockKey: key,
      seat: genericSeat.clamp(1, boatClass.seats),
      side: side,
    ));
    genericSeat++;
  }
  return placements;
}
