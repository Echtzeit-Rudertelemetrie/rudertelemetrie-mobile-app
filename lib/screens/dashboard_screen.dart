import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

import '../components/recording/session_control.dart';
import '../dashboard/add_widget_sheet.dart';
import '../components/dashboart_tiles/angle_gauge_tile.dart';
import '../components/dashboart_tiles/bar_tile.dart';
import '../components/dashboart_tiles/boat_schematic_tile.dart';
import '../components/dashboart_tiles/chart_tile.dart';
import '../components/dashboart_tiles/level_tile.dart';
import '../components/dashboart_tiles/map_tile.dart';
import '../dashboard/dashboard_grid.dart';
import '../dashboard/dashboard_model.dart';
import '../dashboard/preset_sheet.dart';
import '../dashboard/stream_selector_sheet.dart';
import '../components/dashboart_tiles/value_tile.dart';
import '../dashboard/widget_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Cache of bound visualizers keyed by config id + visualizer/source selection.
  /// Prevents rebinding (and resubscription) on every DashboardModel rebuild.
  final Map<String, BoundVisualizer> _boundCache = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Clear stale cache entries whenever the dashboard model notifies.
    // Safe — entries are rebuilt lazily on the next build pass.
    _boundCache.clear();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DashboardModel>();
    final editMode = model.editMode;
    // Rebind tiles when data sources appear/disappear (e.g. a device connects).
    context.watch<DataSourceProviderModel>();

    return FScaffold(
      header: FHeader(
        title: _PresetTitle(
          name: model.activePreset?.name ?? 'Dashboard',
          onTap: () => _showPresetSheet(context, model),
        ),
        suffixes: [
          const SessionControl(),
          FHeaderAction(
            icon: Icon(editMode ? FIcons.check : FIcons.pencil),
            onPress: model.toggleEditMode,
          ),
        ],
      ),
      childPad: false,
      child: Stack(
        children: [
          DashboardGrid(
            widgetBuilder: (context, config) => _buildTile(context, config),
          ),
          if (editMode)
            Positioned(
              right: 16,
              bottom: 24,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFFF45866),
                foregroundColor: Colors.white,
                onPressed: () => _showAddSheet(context, model),
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, WidgetConfig config) {
    final editMode = context.watch<DashboardModel>().editMode;
    final visualizerKey = config.data['visualizerKey'] as String?;
    final sourceKeys =
        (config.data['sourceKeys'] as List<dynamic>?)?.cast<String>() ?? [];
    final type = config.data['type'] as String?;
    final params = _readParams(config.data['params']);

    // Instrument tiles bypass the visualizer pipeline and read sources directly.
    if (type == 'gauge' ||
        type == 'level' ||
        type == 'schematic' ||
        type == 'track') {
      return _buildInstrument(context, type!, sourceKeys);
    }

    final cacheKey =
        '${config.id}_${visualizerKey}_${sourceKeys.join(',')}_${_paramsSignature(params)}';
    final bound = _boundCache[cacheKey] ??
        () {
          final b = _bind(context, visualizerKey, sourceKeys, params);
          if (b != null) _boundCache[cacheKey] = b;
          return b;
        }();

    final content = switch ((type, bound)) {
      ('chart', final BoundVisualizer b) => ChartTile(visualizer: b),
      ('value', final BoundVisualizer b) => ValueTile(visualizer: b),
      ('bar', final BoundVisualizer b) => BarTile(visualizer: b),
      _ => const _NoStreamPlaceholder(),
    };

    if (!editMode) return content;
    return GestureDetector(
      onTap: () => _showStreamSelector(context, config),
      child: content,
    );
  }

  Widget _buildInstrument(
    BuildContext context,
    String type,
    List<String> sourceKeys,
  ) {
    final registry = context.read<DataSourceProviderModel>().registry;
    switch (type) {
      case 'level':
        return LevelTile(registry: registry);
      case 'schematic':
        return BoatSchematicTile(registry: registry);
      case 'track':
        return MapTile(registry: registry);
    }
    final source = sourceKeys.isEmpty ? null : registry.get(sourceKeys.first);
    return source == null
        ? const _NoStreamPlaceholder()
        : AngleGaugeTile(source: source);
  }

  BoundVisualizer? _bind(
    BuildContext context,
    String? visualizerKey,
    List<String> sourceKeys,
    Map<String, double> params,
  ) {
    if (visualizerKey == null) return null;

    final visualizer =
        context.read<VisualizerProviderModel>().registry.get(visualizerKey);
    if (visualizer == null) return null;

    final sourceRegistry = context.read<DataSourceProviderModel>().registry;
    final sources = sourceKeys
        .map((k) => sourceRegistry.get(k))
        .whereType<DataSource>()
        .toList();

    return switch (visualizer) {
      Visualizer1 v when sources.isNotEmpty =>
        v.bind(sources[0], params: params),
      Visualizer2 v when sources.length >= 2 =>
        v.bind(sources[0], sources[1], params: params),
      _ => null,
    };
  }

  Map<String, double> _readParams(dynamic raw) {
    if (raw is! Map) return const {};
    final params = <String, double>{};
    raw.forEach((key, value) {
      if (value is num) params[key.toString()] = value.toDouble();
    });
    return params;
  }

  String _paramsSignature(Map<String, double> params) {
    final keys = params.keys.toList()..sort();
    return keys.map((k) => '$k=${params[k]}').join(',');
  }

  void _showStreamSelector(BuildContext context, WidgetConfig config) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<DashboardModel>(),
        child: StreamSelectorSheet(config: config),
      ),
    );
  }

  void _showPresetSheet(BuildContext context, DashboardModel model) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: model,
        child: const PresetSheet(),
      ),
    );
  }

  void _showAddSheet(BuildContext context, DashboardModel model) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: model,
        child: const AddWidgetSheet(),
      ),
    );
  }
}

/// Dashboard title doubling as the preset switcher.
class _PresetTitle extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _PresetTitle({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 4),
        const Icon(FIcons.chevronDown, size: 16),
      ],
    ),
  );
}

class _NoStreamPlaceholder extends StatelessWidget {
  const _NoStreamPlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.add_chart, color: Colors.white24, size: 28),
  );
}
