import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/force_angle_source_pair.dart';

void main() {
  PushDataSource source(String name, Unit unit, String group) =>
      PushDataSource(name: name, unit: unit, group: group);

  test('creates only angle/force pairs from the same oarlock', () {
    final sources = [
      source('Angle A', Unit.deg, 'Oarlock A'),
      source('Force A', Unit.N, 'Oarlock A'),
      source('Angle B', Unit.deg, 'Oarlock B'),
      source('Speed', Unit.mps, 'Boat'),
    ];

    final pairs = forceAngleSourcePairs(sources);

    expect(pairs, hasLength(1));
    expect(pairs.single.sourceKeys, ['Angle A', 'Force A']);
  });

  test('repairs a reversed legacy selection to angle X and force Y', () {
    final sources = [
      source('Angle A', Unit.deg, 'Oarlock A'),
      source('Force A', Unit.N, 'Oarlock A'),
    ];

    final pair = resolveForceAngleSourcePair(sources, const [
      'Force A',
      'Angle A',
    ]);

    expect(pair?.sourceKeys, ['Angle A', 'Force A']);
  });
}
