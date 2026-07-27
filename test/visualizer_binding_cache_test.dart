import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/visualizer_binding_cache.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

BoundVisualizer _bound(String name) => BoundVisualizer(
  name: name,
  units: (x: Unit.s, y: Unit.N),
  output: const Stream.empty(),
);

String _signature({
  String? visualizerKey = 'force',
  List<String> sourceKeys = const ['Force 1'],
  List<DataSource> sources = const [],
  Map<String, double> params = const {'window': 10},
}) => bindingSignature(
  visualizerKey: visualizerKey,
  sourceKeys: sourceKeys,
  sources: sources,
  params: params,
);

void main() {
  late VisualizerBindingCache cache;
  late int builds;

  BoundVisualizer? bindTile(String id, String signature) =>
      cache.bind(id, signature, () {
        builds++;
        return _bound(id);
      });

  setUp(() {
    cache = VisualizerBindingCache();
    builds = 0;
  });

  test('an unchanged signature reuses the binding', () {
    final first = bindTile('tile_1', _signature());
    final second = bindTile('tile_1', _signature());

    expect(identical(first, second), isTrue);
    expect(builds, 1);
  });

  test('changed params, sources or visualizer rebind', () {
    bindTile('tile_1', _signature());
    bindTile('tile_1', _signature(params: const {'window': 20}));
    bindTile('tile_1', _signature(sourceKeys: const ['Force 2']));
    bindTile('tile_1', _signature(visualizerKey: 'power'));

    expect(builds, 4);
  });

  test('a replaced source instance rebinds, an unchanged one does not', () {
    final original = PushDataSource(name: 'Force 1', unit: Unit.N);
    bindTile('tile_1', _signature(sources: [original]));
    bindTile('tile_1', _signature(sources: [original]));
    expect(builds, 1);

    final reconnected = PushDataSource(name: 'Force 1', unit: Unit.N);
    bindTile('tile_1', _signature(sources: [reconnected]));
    expect(builds, 2);
  });

  test('a failed bind is not cached', () {
    cache.bind('tile_1', _signature(), () => null);
    expect(cache.length, 0);
  });

  test('retainOnly drops bindings of deleted tiles', () {
    bindTile('tile_1', _signature());
    bindTile('tile_2', _signature());
    expect(cache.length, 2);

    cache.retainOnly({'tile_1'});
    expect(cache.length, 1);

    bindTile('tile_1', _signature());
    expect(builds, 2); // tile_1 survived the eviction
  });
}
