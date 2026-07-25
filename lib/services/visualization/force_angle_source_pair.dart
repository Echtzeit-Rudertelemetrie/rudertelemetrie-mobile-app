import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

class ForceAngleSourcePair {
  final DataSource angle;
  final DataSource force;

  const ForceAngleSourcePair({required this.angle, required this.force});

  String get label => angle.group ?? angle.name;
  List<String> get sourceKeys => [angle.name, force.name];
}

List<ForceAngleSourcePair> forceAngleSourcePairs(Iterable<DataSource> sources) {
  final byGroup = <String, List<DataSource>>{};
  for (final source in sources) {
    final group = source.group;
    if (group == null) continue;
    (byGroup[group] ??= []).add(source);
  }

  final pairs = <ForceAngleSourcePair>[];
  for (final entry in byGroup.entries) {
    final angle = entry.value
        .where((source) => source.unit == Unit.deg)
        .firstOrNull;
    final force = entry.value
        .where((source) => source.unit == Unit.N)
        .firstOrNull;
    if (angle != null && force != null) {
      pairs.add(ForceAngleSourcePair(angle: angle, force: force));
    }
  }
  return pairs;
}

ForceAngleSourcePair? resolveForceAngleSourcePair(
  Iterable<DataSource> sources,
  Iterable<String> selectedKeys,
) {
  final selected = selectedKeys.toSet();
  final pairs = forceAngleSourcePairs(sources);
  for (final pair in pairs) {
    if (selected.contains(pair.angle.name) ||
        selected.contains(pair.force.name)) {
      return pair;
    }
  }
  return pairs.length == 1 ? pairs.single : null;
}
