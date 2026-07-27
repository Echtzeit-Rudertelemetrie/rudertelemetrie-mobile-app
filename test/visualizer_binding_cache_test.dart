import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/speed_settings_model.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/visualizer_binding_cache.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/speed_data_source.dart';
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

  test('a source that switches unit rebinds', () {
    final settings = SpeedSettingsModel();
    final speed = SpeedDataSource(name: 'Speed (ABCD)', settings: settings);
    addTearDown(speed.dispose);

    bindTile('tile_1', _signature(sources: [speed]));
    bindTile('tile_1', _signature(sources: [speed]));
    expect(builds, 1);

    settings.setDisplayUnit(SpeedDisplayUnit.pace500m);
    bindTile('tile_1', _signature(sources: [speed]));
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

  group('a dropped binding is released', () {
    /// A binding whose upstream never completes, so only [BoundVisualizer.dispose]
    /// can end its subscription.
    (BoundVisualizer, StreamController<List<XYPoint>>) live() {
      final upstream = StreamController<List<XYPoint>>();
      return (
        BoundVisualizer(
          name: 'live',
          units: (x: Unit.s, y: Unit.N),
          output: upstream.stream,
        ),
        upstream,
      );
    }

    test('when its signature changes', () async {
      final (bound, upstream) = live();
      cache.bind('tile_1', _signature(), () => bound);
      bound.output.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(upstream.hasListener, isTrue);

      cache.bind('tile_1', _signature(params: const {'window': 20}), () {
        final (next, _) = live();
        return next;
      });

      expect(upstream.hasListener, isFalse);
    });

    test('when the tile leaves the dashboard', () async {
      final (bound, upstream) = live();
      cache.bind('tile_1', _signature(), () => bound);
      bound.output.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      cache.retainOnly(const {});

      expect(upstream.hasListener, isFalse);
    });

    test('when the screen clears the cache', () async {
      final (bound, upstream) = live();
      cache.bind('tile_1', _signature(), () => bound);
      bound.output.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      cache.clear();

      expect(cache.length, 0);
      expect(upstream.hasListener, isFalse);
    });
  });
}
