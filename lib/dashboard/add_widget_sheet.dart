import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

import 'dashboard_model.dart';
import 'sheet_scaffold.dart';
import 'source_picker.dart';
import 'tile_kind.dart';
import 'tile_kind_step.dart';
import 'widget_config.dart';
import 'widget_config_draft.dart';
import 'widget_config_fields.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Adds a widget in steps: first what kind of tile, then whatever that kind
/// still needs. A kind that needs nothing is placed straight from step one.
class AddWidgetSheet extends StatefulWidget {
  const AddWidgetSheet({super.key});

  @override
  State<AddWidgetSheet> createState() => _AddWidgetSheetState();
}

class _AddWidgetSheetState extends State<AddWidgetSheet> {
  /// New tiles start at a single portrait cell so a tile fits wherever the grid
  /// still has room. The user resizes it afterwards. Landscape's finer columns
  /// are a smaller step, not a smaller tile — hence the scaling in [_place].
  static const int _newTileW = 1;
  static const int _newTileH = 1;

  final _draft = WidgetConfigDraft();

  /// Null while the kind is still being chosen.
  TileKind? _kind;

  AnyVisualizer? get _selectedVisualizer {
    final key = _draft.visualizerKey;
    if (key == null) return null;
    return context.read<VisualizerProviderModel>().registry.get(key);
  }

  void _select(TileKind kind) {
    switch (kind.input) {
      case TileInput.none:
        _addTile(context, kind);
      case TileInput.source:
        setState(() {
          _draft.selectSingleSource();
          _kind = kind;
        });
      case TileInput.visualizer:
        setState(() {
          _prepareVisualizer(kind);
          _kind = kind;
        });
    }
  }

  /// A visualizer tile opens on one this kind can actually draw, rather than on
  /// nothing. A pick the user already made survives a trip back to step one, as
  /// long as the kind they came back with can still draw it.
  void _prepareVisualizer(TileKind kind) {
    final options = kind.visualizersFrom(_visualizers);
    if (options.any((v) => v.name == _draft.visualizerKey)) return;
    if (options.isNotEmpty) _draft.selectVisualizer(options.first);
  }

  List<AnyVisualizer> get _visualizers =>
      context.read<VisualizerProviderModel>().registry.all;

  void _addTile(BuildContext context, TileKind kind) {
    switch (kind.input) {
      case TileInput.visualizer:
        _place(
          context,
          _draft.toData(
            type: kind.key,
            registry: context.read<DataSourceProviderModel>().registry,
            session: context.read<RecordingSession>(),
          ),
        );
      case TileInput.source:
        _placeSimple(context, kind, [
          _draft.sourceKeys.whereType<String>().first,
        ]);
      case TileInput.none:
        _placeSimple(context, kind, const []);
    }
  }

  /// Instrument tiles bypass the visualizer pipeline and just carry their
  /// source keys.
  void _placeSimple(BuildContext context, TileKind kind, List<String> keys) =>
      _place(context, {'type': kind.key, 'sourceKeys': keys});

  bool _canAdd(TileKind kind) => switch (kind.input) {
    TileInput.visualizer => _draft.isComplete,
    TileInput.source => _draft.hasSource,
    TileInput.none => true,
  };

  void _place(BuildContext context, Map<String, dynamic> data) {
    final model = context.read<DashboardModel>();
    final placed = model.addWidget(
      WidgetConfig(
        id: 'w_${DateTime.now().millisecondsSinceEpoch}',
        x: 0,
        y: 0,
        w: _newTileW * model.columnStep,
        h: _newTileH,
        data: data,
      ),
    );
    _reportPlacement(context, placed);
  }

  /// The dashboard is one fixed viewport, so it refuses a tile as soon as the
  /// grid is full — and when it does, the user hears about it instead of
  /// watching the tile disappear under another.
  void _reportPlacement(BuildContext context, bool placed) {
    if (!placed) {
      context.read<AppNotifications>().alert(
        'Dashboard full',
        detail: 'Remove a widget or create a new preset.',
      );
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    if (kind == null) return _kindStep();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _kind = null);
      },
      child: _configureStep(context, kind),
    );
  }

  Widget _kindStep() => SheetScaffold(
    title: 'Add Widget',
    initialSize: 0.7,
    children: [TileKindStep(onSelected: _select)],
  );

  Widget _configureStep(BuildContext context, TileKind kind) => SheetScaffold(
    title: kind.label,
    initialSize: 0.7,
    onBack: () => setState(() => _kind = null),
    footer: SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppPalette.accent),
        onPressed: _canAdd(kind) ? () => _addTile(context, kind) : null,
        child: Text('Add ${kind.label}'),
      ),
    ),
    children: [_configureFields(context, kind)],
  );

  Widget _configureFields(BuildContext context, TileKind kind) {
    final dataSources = context.watch<DataSourceProviderModel>().registry.all;
    if (kind.input == TileInput.source) {
      return SourcePicker(
        sources: dataSources,
        requirement: kind.sourceRequirement,
        selectedKey: _draft.sourceKeys.firstOrNull,
        onSelected: (key) => setState(() => _draft.sourceKeys[0] = key),
      );
    }

    return WidgetConfigFields(
      kind: kind,
      draft: _draft,
      visualizers: _visualizers,
      selected: _selectedVisualizer,
      dataSources: dataSources,
      onChanged: () => setState(() {}),
    );
  }
}
