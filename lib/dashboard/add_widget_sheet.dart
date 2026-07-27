import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

import 'dashboard_model.dart';
import 'sheet_scaffold.dart';
import 'widget_config.dart';
import 'widget_config_draft.dart';
import 'widget_config_fields.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

class AddWidgetSheet extends StatefulWidget {
  const AddWidgetSheet({super.key});

  @override
  State<AddWidgetSheet> createState() => _AddWidgetSheetState();
}

class _AddWidgetSheetState extends State<AddWidgetSheet> {
  /// New tiles start at a single cell so a tile fits wherever the grid still
  /// has a free cell. The user resizes it afterwards.
  static const int _newTileW = 1;
  static const int _newTileH = 1;

  final _draft = WidgetConfigDraft();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visualizers = context.read<VisualizerProviderModel>().registry.all;
    if (_draft.visualizerKey == null && visualizers.isNotEmpty) {
      _draft.selectVisualizer(visualizers.first);
    }
  }

  AnyVisualizer? get _selectedVisualizer {
    final key = _draft.visualizerKey;
    if (key == null) return null;
    return context.read<VisualizerProviderModel>().registry.get(key);
  }

  void _add(BuildContext context, String type) {
    _place(
      context,
      _draft.toData(
        type: type,
        registry: context.read<DataSourceProviderModel>().registry,
        session: context.read<RecordingSession>(),
      ),
    );
  }

  /// Instrument tiles bypass the visualizer pipeline and just carry their
  /// source keys.
  void _addSimple(BuildContext context, String type, List<String> keys) =>
      _place(context, {'type': type, 'sourceKeys': keys});

  void _addGauge(BuildContext context) {
    final keys = _draft.sourceKeys.whereType<String>().toList();
    if (keys.isEmpty) return;
    _addSimple(context, 'gauge', [keys.first]);
  }

  void _place(BuildContext context, Map<String, dynamic> data) {
    final placed = context.read<DashboardModel>().addWidget(
      WidgetConfig(
        id: 'w_${DateTime.now().millisecondsSinceEpoch}',
        x: 0,
        y: 0,
        w: _newTileW,
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
    final canAdd = _draft.isComplete;
    final hasSource = _draft.hasSource;

    return SheetScaffold(
      title: 'Add Widget',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _AddButton(
                  icon: Icons.show_chart,
                  label: 'Chart',
                  enabled: canAdd,
                  onTap: canAdd ? () => _add(context, 'chart') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AddButton(
                  icon: Icons.pin,
                  label: 'Value',
                  enabled: canAdd,
                  onTap: canAdd ? () => _add(context, 'value') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AddButton(
                  icon: Icons.bar_chart,
                  label: 'Bar',
                  enabled: canAdd,
                  onTap: canAdd ? () => _add(context, 'bar') : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AddButton(
                  icon: Icons.speed,
                  label: 'Gauge',
                  enabled: hasSource,
                  onTap: hasSource ? () => _addGauge(context) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AddButton(
                  icon: Icons.explore,
                  label: 'Level',
                  enabled: true,
                  onTap: () => _addSimple(context, 'level', const []),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AddButton(
                  icon: Icons.rowing,
                  label: 'Boat',
                  enabled: true,
                  onTap: () => _addSimple(context, 'schematic', const []),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AddButton(
                  icon: Icons.map,
                  label: 'Map',
                  enabled: true,
                  onTap: () => _addSimple(context, 'track', const []),
                ),
              ),
            ],
          ),
        ],
      ),
      children: [
        WidgetConfigFields(
          draft: _draft,
          visualizers: context.read<VisualizerProviderModel>().registry.all,
          selected: _selectedVisualizer,
          dataSources: context.watch<DataSourceProviderModel>().registry.all,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _AddButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.accent.withAlpha(enabled ? 30 : 10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppPalette.accent.withAlpha(enabled ? 80 : 30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppPalette.accent.withAlpha(enabled ? 255 : 100),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppPalette.accent.withAlpha(enabled ? 255 : 100),
              fontSize: AppTypeScale.caption,
            ),
          ),
        ],
      ),
    ),
  );
}
