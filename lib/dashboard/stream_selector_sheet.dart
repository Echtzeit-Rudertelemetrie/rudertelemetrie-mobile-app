import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

import 'dashboard_model.dart';
import 'sheet_scaffold.dart';
import 'tile_kind.dart';
import 'widget_config.dart';
import 'widget_config_draft.dart';
import 'widget_config_fields.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

class StreamSelectorSheet extends StatefulWidget {
  final WidgetConfig config;

  const StreamSelectorSheet({super.key, required this.config});

  @override
  State<StreamSelectorSheet> createState() => _StreamSelectorSheetState();
}

class _StreamSelectorSheetState extends State<StreamSelectorSheet> {
  static final _kinds = TileKind.values
      .where((kind) => kind.input == TileInput.visualizer)
      .toList();

  late TileKind _kind;
  late WidgetConfigDraft _draft;

  @override
  void initState() {
    super.initState();
    _kind =
        TileKind.fromKey(widget.config.data['type'] as String?) ??
        TileKind.value;
    _draft = WidgetConfigDraft.fromData(
      widget.config.data,
      context.read<DataSourceProviderModel>().registry,
    );
  }

  /// A visualizer whose shape changed since the widget was stored is reconciled
  /// here — not in [initState], which cannot reach the registry a second time.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _draft.syncTo(_selectedVisualizer);
  }

  AnyVisualizer? get _selectedVisualizer {
    final key = _draft.visualizerKey;
    if (key == null) return null;
    return context.read<VisualizerProviderModel>().registry.get(key);
  }

  void _apply() {
    context.read<DashboardModel>().updateWidget(
      widget.config.copyWith(
        data: _draft.toData(
          type: _kind.key,
          registry: context.read<DataSourceProviderModel>().registry,
          session: context.read<RecordingSession>(),
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Configure Widget',
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppPalette.accent),
          onPressed: _draft.isComplete ? _apply : null,
          child: const Text('Apply'),
        ),
      ),
      children: [
        const Text(
          'Display type',
          style: TextStyle(
            color: AppPalette.faintLabel,
            fontSize: AppTypeScale.caption,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          spacing: 8,
          children: [
            for (final kind in _kinds)
              _TypeButton(
                label: kind.label,
                icon: kind.icon,
                selected: _kind == kind,
                onTap: () => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: 16),
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

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppPalette.accent : AppPalette.gridLine,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? AppPalette.label : AppPalette.faintLabel,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppPalette.label : AppPalette.faintLabel,
              fontSize: AppTypeScale.label,
            ),
          ),
        ],
      ),
    ),
  );
}
