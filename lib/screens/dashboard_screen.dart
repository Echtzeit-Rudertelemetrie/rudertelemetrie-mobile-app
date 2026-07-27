import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/models/speed_settings_model.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/screens/rig_setup_screen.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oarlocks.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/force_angle_source_pair.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

import '../components/recording/session_control.dart';
import '../dashboard/add_widget_sheet.dart';
import '../components/dashboard_tiles/angle_gauge_tile.dart';
import '../components/dashboard_tiles/bar_tile.dart';
import '../components/dashboard_tiles/boat_schematic_tile.dart';
import '../components/dashboard_tiles/chart_tile.dart';
import '../components/dashboard_tiles/level_tile.dart';
import '../components/dashboard_tiles/map_tile.dart';
import '../dashboard/dashboard_grid.dart';
import '../dashboard/dashboard_model.dart';
import '../dashboard/preset_sheet.dart';
import '../dashboard/stream_selector_sheet.dart';
import '../components/dashboard_tiles/value_tile.dart';
import '../dashboard/visualizer_binding_cache.dart';
import '../dashboard/widget_config.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _bindings = VisualizerBindingCache();

  @override
  void dispose() {
    _bindings.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DashboardModel>();
    final editMode = model.editMode;
    // Rebind tiles when data sources appear/disappear (e.g. a device connects).
    context.watch<DataSourceProviderModel>();
    // The speed source reports its unit from this setting, and a binding reads
    // that unit once — so a change here has to reach the bound tiles.
    context.watch<SpeedSettingsModel>();
    _bindings.retainOnly({for (final config in model.layout) config.id});

    return FScaffold(
      header: FHeader.nested(
        title: _PresetTitle(
          name: model.activePreset?.name ?? 'Dashboard',
          onTap: () => _showPresetSheet(context, model),
        ),
        prefixes: [
          FHeaderAction(
            icon: const Icon(FIcons.x),
            semanticsLabel: 'Close dashboard',
            onPress: () => Navigator.pop(context),
          ),
        ],
        suffixes: [
          const SessionControl(),
          FHeaderAction(
            icon: Icon(editMode ? FIcons.check : FIcons.pencil),
            semanticsLabel: editMode ? 'Finish editing' : 'Edit dashboard',
            onPress: model.toggleEditMode,
          ),
        ],
      ),
      childPad: false,
      child: Stack(
        children: [
          Column(
            children: [
              const _RigBanner(),
              Expanded(
                child: DashboardGrid(
                  widgetBuilder: (context, config) =>
                      _buildTile(context, config),
                ),
              ),
            ],
          ),
          if (editMode)
            Positioned(
              right: 16,
              bottom: 24,
              child: FloatingActionButton(
                backgroundColor: AppPalette.accent,
                foregroundColor: AppPalette.label,
                tooltip: 'Add widget',
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

    final visualizer = visualizerKey == null
        ? null
        : context.read<VisualizerProviderModel>().registry.get(visualizerKey);
    final sources = _resolveSources(context, visualizer, sourceKeys);
    final bound = _bindings.bind(
      config.id,
      bindingSignature(
        visualizerKey: visualizerKey,
        sourceKeys: sourceKeys,
        sources: sources,
        params: params,
      ),
      () => _bind(visualizer, sources, params),
    );

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

  /// Force/angle visualizers store one oarlock's two keys but must survive the
  /// pair being renamed or re-registered, so they re-resolve through the group
  /// instead of trusting the stored names.
  List<DataSource> _resolveSources(
    BuildContext context,
    AnyVisualizer? visualizer,
    List<String> keys,
  ) {
    final registry = context.read<DataSourceProviderModel>().registry;
    if (visualizer?.sourceSelectionMode == SourceSelectionMode.forceAnglePair) {
      final pair = resolveForceAngleSourcePair(registry.all, keys);
      return pair == null ? const [] : [pair.angle, pair.force];
    }
    return keys.map(registry.get).whereType<DataSource>().toList();
  }

  BoundVisualizer? _bind(
    AnyVisualizer? visualizer,
    List<DataSource> sources,
    Map<String, double> params,
  ) {
    if (visualizer == null) return null;

    return switch (visualizer) {
      Visualizer1 v when sources.isNotEmpty => v.bind(
        sources[0],
        params: params,
      ),
      Visualizer2 v when sources.length >= 2 => v.bind(
        sources[0],
        sources[1],
        params: params,
      ),
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
  Widget build(BuildContext context) => Semantics(
    label: 'Dashboard preset: $name. Tap to switch.',
    button: true,
    child: GestureDetector(
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
    ),
  );
}

/// Says out loud what an unconfigured rig costs, instead of letting the force
/// and power tiles sit blank with no explanation.
class _RigBanner extends StatelessWidget {
  const _RigBanner();

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<DataSourceProviderModel>().registry;
    final config = context.watch<BoatConfig>();
    final pending = oarlocksNeedingRig(registry, config);
    if (pending.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RigSetupScreen()),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        color: Colors.amber.withAlpha(40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(FIcons.triangleAlert, color: Colors.amber, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Rig incomplete for ${pending.join(', ')} — force and power '
                'sources unavailable. Tap to set it up.',
                style: const TextStyle(color: Colors.amber, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoStreamPlaceholder extends StatelessWidget {
  const _NoStreamPlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.add_chart, color: Colors.white24, size: 28),
  );
}
