import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_model.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_preset.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_preset_store.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_config.dart';

/// In-memory stand-in for [FileDashboardPresetStore].
class FakePresetStore implements DashboardPresetStore {
  DashboardPresetData? data;
  int saves = 0;

  @override
  Future<DashboardPresetData?> load() async => data;

  @override
  Future<void> save(DashboardPresetData data) async {
    this.data = data;
    saves++;
  }
}

WidgetConfig _tile(String id, {int x = 0, int y = 0}) =>
    WidgetConfig(id: id, x: x, y: y, w: 1, h: 1, data: {'type': 'value'});

Future<DashboardModel> _loaded(FakePresetStore store) async {
  final model = DashboardModel(store: store);
  await model.load();
  return model;
}

void main() {
  group('preset lifecycle', () {
    test('load without saved data creates one default preset', () async {
      final model = await _loaded(FakePresetStore());

      expect(model.presets, hasLength(1));
      expect(model.presets.single.name, DashboardModel.defaultPresetName);
      expect(model.activePresetId, model.presets.single.id);
      expect(model.layout, isEmpty);
    });

    test('creating a preset switches to it and starts empty', () async {
      final model = await _loaded(FakePresetStore());
      model.addWidget(_tile('a'));

      model.createPreset('Race');

      expect(model.presets, hasLength(2));
      expect(model.activePreset!.name, 'Race');
      expect(model.layout, isEmpty);
    });

    test(
      'duplicating carries the current layout into the new preset',
      () async {
        final model = await _loaded(FakePresetStore());
        model.addWidget(_tile('a'));

        model.createPreset('Race', copyCurrent: true);

        expect(model.layout.map((w) => w.id), ['a']);
        expect(model.presets.first.layout.map((w) => w.id), ['a']);
      },
    );

    test('renaming trims and ignores an empty name', () async {
      final model = await _loaded(FakePresetStore());
      final id = model.activePresetId!;

      model.renamePreset(id, '  Technique  ');
      expect(model.activePreset!.name, 'Technique');

      model.renamePreset(id, '   ');
      expect(model.activePreset!.name, 'Technique');
    });

    test('deleting the active preset falls back to a remaining one', () async {
      final model = await _loaded(FakePresetStore());
      final first = model.activePresetId!;
      model.createPreset('Race');

      model.deletePreset(model.activePresetId!);

      expect(model.presets, hasLength(1));
      expect(model.activePresetId, first);
    });

    test('the last preset cannot be deleted', () async {
      final model = await _loaded(FakePresetStore());

      model.deletePreset(model.activePresetId!);

      expect(model.presets, hasLength(1));
    });
  });

  group('swapping presets', () {
    test('each preset keeps its own layout', () async {
      final model = await _loaded(FakePresetStore());
      final first = model.activePresetId!;
      model.addWidget(_tile('a'));

      model.createPreset('Race');
      model.addWidget(_tile('b'));
      final second = model.activePresetId!;

      model.selectPreset(first);
      expect(model.layout.map((w) => w.id), ['a']);

      model.selectPreset(second);
      expect(model.layout.map((w) => w.id), ['b']);
    });

    test('edits after a swap do not leak into the previous preset', () async {
      final model = await _loaded(FakePresetStore());
      final first = model.activePresetId!;
      model.addWidget(_tile('a'));

      model.createPreset('Race');
      model.removeWidget('a');
      model.addWidget(_tile('b'));

      model.selectPreset(first);
      expect(model.layout.map((w) => w.id), ['a']);
    });

    test('selecting an unknown id is ignored', () async {
      final model = await _loaded(FakePresetStore());
      final active = model.activePresetId;

      model.selectPreset('nope');

      expect(model.activePresetId, active);
    });
  });

  group('persistence', () {
    test('layout edits are written through to the store', () async {
      final store = FakePresetStore();
      final model = await _loaded(store);

      model.addWidget(_tile('a'));

      expect(store.data!.presets.single.layout.map((w) => w.id), ['a']);
      expect(store.data!.activeId, model.activePresetId);
    });

    test('a reloaded model restores presets and the active one', () async {
      final store = FakePresetStore();
      final first = await _loaded(store);
      first.addWidget(_tile('a'));
      first.createPreset('Race', copyCurrent: true);
      first.addWidget(_tile('b', y: 1));
      final activeId = first.activePresetId;

      final restored = await _loaded(store);

      expect(restored.presets.map((p) => p.name), [
        DashboardModel.defaultPresetName,
        'Race',
      ]);
      expect(restored.activePresetId, activeId);
      expect(restored.layout.map((w) => w.id), ['a', 'b']);
    });

    test('presets survive a JSON round-trip with widget data intact', () {
      final preset = DashboardPreset(
        id: 'p1',
        name: 'Race',
        layout: [
          const WidgetConfig(
            id: 'w1',
            x: 1,
            y: 2,
            w: 2,
            h: 3,
            data: {
              'type': 'chart',
              'visualizerKey': 'Time Window',
              'sourceKeys': ['Force 1 (1A2B)'],
              'params': {'windowSeconds': 20.0},
            },
          ),
        ],
      );

      final decoded = DashboardPreset.fromJson(preset.toJson());
      final widget = decoded.layout.single;

      expect(decoded.name, 'Race');
      expect(widget.id, 'w1');
      expect(widget.x, 1);
      expect(widget.h, 3);
      expect(widget.data['visualizerKey'], 'Time Window');
      expect(widget.data['sourceKeys'], ['Force 1 (1A2B)']);
      expect(widget.data['params'], {'windowSeconds': 20.0});
    });
  });
}
