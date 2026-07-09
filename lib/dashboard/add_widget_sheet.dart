import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

import 'dashboard_model.dart';
import 'sheet_scaffold.dart';
import 'widget_config.dart';

class AddWidgetSheet extends StatefulWidget {
  const AddWidgetSheet({super.key});

  @override
  State<AddWidgetSheet> createState() => _AddWidgetSheetState();
}

class _AddWidgetSheetState extends State<AddWidgetSheet> {
  String? _visualizerKey;
  List<String?> _sourceKeys = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visualizers = context.read<VisualizerProviderModel>().registry.all;
    if (_visualizerKey == null && visualizers.isNotEmpty) {
      _visualizerKey = visualizers.first.name;
      _sourceKeys = List.filled(visualizers.first.sourceCount, null);
    }
  }

  AnyVisualizer? get _selectedVisualizer {
    if (_visualizerKey == null) return null;
    return context.read<VisualizerProviderModel>().registry.get(_visualizerKey!);
  }

  bool get _canAdd =>
      _visualizerKey != null && _sourceKeys.every((k) => k != null);

  void _selectVisualizer(AnyVisualizer v) {
    setState(() {
      _visualizerKey = v.name;
      _sourceKeys = List.filled(v.sourceCount, null);
    });
  }

  void _add(BuildContext context, String type, int w, int h) {
    final id = 'w_${DateTime.now().millisecondsSinceEpoch}';
    context.read<DashboardModel>().addWidget(
      WidgetConfig(
        id: id,
        x: 0,
        y: 0,
        w: w,
        h: h,
        data: {
          'type': type,
          'visualizerKey': _visualizerKey,
          'sourceKeys': List<String>.from(_sourceKeys.whereType<String>()),
        },
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final visualizers = context.read<VisualizerProviderModel>().registry.all;
    final dataSources = context.watch<DataSourceProviderModel>().registry.all;
    final sourceCount = _selectedVisualizer?.sourceCount ?? 0;

    return SheetScaffold(
      title: 'Add Widget',
      footer: Row(
        children: [
          Expanded(
            child: _AddButton(
              icon: Icons.show_chart,
              label: 'Chart',
              enabled: _canAdd,
              onTap: _canAdd ? () => _add(context, 'chart', 2, 3) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AddButton(
              icon: Icons.pin,
              label: 'Value',
              enabled: _canAdd,
              onTap: _canAdd ? () => _add(context, 'value', 2, 2) : null,
            ),
          ),
        ],
      ),
      children: [
        const Text(
          'Visualizer',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        ...visualizers.map((v) => _VisualizerOption(
              visualizer: v,
              selected: _visualizerKey == v.name,
              onTap: () => _selectVisualizer(v),
            )),
        const SizedBox(height: 16),

        for (int i = 0; i < sourceCount; i++) ...[
          Text(
            sourceCount == 1 ? 'Data source' : 'Data source ${i + 1}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          if (dataSources.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No streams available.',
                style: TextStyle(color: Colors.white38),
              ),
            )
          else
            ...dataSources.map((ds) => _SourceOption(
                  dataSource: ds,
                  selected: _sourceKeys[i] == ds.name,
                  onTap: () => setState(() => _sourceKeys[i] = ds.name),
                )),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _VisualizerOption extends StatelessWidget {
  final AnyVisualizer visualizer;
  final bool selected;
  final VoidCallback onTap;

  const _VisualizerOption({
    required this.visualizer,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _Radio(selected: selected),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visualizer.name,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                '${visualizer.sourceCount} source${visualizer.sourceCount == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SourceOption extends StatelessWidget {
  final DataSource dataSource;
  final bool selected;
  final VoidCallback onTap;

  const _SourceOption({
    required this.dataSource,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _Radio(selected: selected),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dataSource.name,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                dataSource.unit.name,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Radio extends StatelessWidget {
  final bool selected;
  const _Radio({required this.selected});

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? const Color(0xFFF45866) : Colors.white38,
        width: 2,
      ),
    ),
    child: selected
        ? const Center(
            child: CircleAvatar(radius: 5, backgroundColor: Color(0xFFF45866)),
          )
        : null,
  );
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
        color: const Color(0xFFF45866).withAlpha(enabled ? 30 : 10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF45866).withAlpha(enabled ? 80 : 30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color: Color(0xFFF45866).withAlpha(enabled ? 255 : 100),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Color(0xFFF45866).withAlpha(enabled ? 255 : 100),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}
