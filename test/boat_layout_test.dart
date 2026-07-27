import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_layout.dart';

void main() {
  test('uses assigned slots when present', () {
    final placements = computeBoatLayout(
      boatClass: BoatClass.pair,
      slots: {
        'Oarlock 1 (T)': const SeatSlot(seat: 1, side: OarSide.starboard),
        'Oarlock 2 (T)': const SeatSlot(seat: 2, side: OarSide.port),
      },
      oarlockKeys: ['Oarlock 1 (T)', 'Oarlock 2 (T)'],
    );
    expect(placements.map((p) => (p.seat, p.side)), [
      (1, OarSide.starboard),
      (2, OarSide.port),
    ]);
  });

  test('generic scull fallback: sequential seats, both sides', () {
    final placements = computeBoatLayout(
      boatClass: BoatClass.double_,
      slots: const {},
      oarlockKeys: ['Oarlock 1 (T)', 'Oarlock 2 (T)'],
    );
    expect(placements.map((p) => p.seat), [1, 2]);
    expect(placements.every((p) => p.side == OarSide.both), isTrue);
  });

  test('generic sweep fallback: alternating sides', () {
    final placements = computeBoatLayout(
      boatClass: BoatClass.four,
      slots: const {},
      oarlockKeys: ['Oarlock 1 (T)', 'Oarlock 2 (T)'],
    );
    expect(placements.map((p) => p.side), [OarSide.starboard, OarSide.port]);
  });

  test('boat classes expose seat counts and sculling flag', () {
    expect(BoatClass.single.seats, 1);
    expect(BoatClass.eight.seats, 8);
    expect(BoatClass.quad.isSculling, isTrue);
    expect(BoatClass.pair.isSculling, isFalse);
  });
}
