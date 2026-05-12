import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

import 'dashboard_model.dart';
import 'widget_config.dart';

class StreamSelectorSheet extends StatefulWidget {
  final WidgetConfig config;

  const StreamSelectorSheet({super.key, required this.config});

  @override
  State<StreamSelectorSheet> createState() => _StreamSelectorSheetState();
}

class _StreamSelectorSheetState extends State<StreamSelectorSheet> {
  late String _type;
  late String? _visualizerKey;
  late List<String?> _sourceKeys;

  @override
  void initState() {
    super.initState();
    _type = widget.config.data['type'] as String? ?? 'value';
    _visualizerKey = widget.config.data['visualizerKey'] as String?;
    final stored =
        (widget.config.data['sourceKeys'] as List<dynamic>?)?.cast<String>();
    _sourceKeys = stored != null ? List<String?>.from(stored) : [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSourceKeysToVisualizer();
  }

  void _syncSourceKeysToVisualizer() {
    final v = _selectedVisualizer;
    if (v == null) return;
    final count = v.sourceCount;
    if (_sourceKeys.length < count) {
      _sourceKeys = [
        ..._sourceKeys,
        ...List.filled(count - _sourceKeys.length, null),
      ];
    } else if (_sourceKeys.length > count) {
      _sourceKeys = _sourceKeys.sublist(0, count);
    }
  }

  AnyVisualizer? get _selectedVisualizer {
    if (_visualizerKey == null) return null;
    return context.read<VisualizerProviderModel>().registry.get(_visualizerKey!);
  }

  void _selectVisualizer(AnyVisualizer v) {
    setState(() {
      _visualizerKey = v.name;
      _sourceKeys = List.filled(v.sourceCount, null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visualizers = context.read<VisualizerProviderModel>().registry.all;
    final dataSources = context.read<DataSourceProviderModel>().registry.all;
    final sourceCount = _selectedVisualizer?.sourceCount ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure Widget',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Display type',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _TypeButton(
                  label: 'Chart',
                  icon: Icons.show_chart,
                  selected: _type == 'chart',
                  onTap: () => setState(() => _type = 'chart'),
                ),
                const SizedBox(width: 8),
                _TypeButton(
                  label: 'Value',
                  icon: Icons.pin,
                  selected: _type == 'value',
                  onTap: () => setState(() => _type = 'value'),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
                      selected: i < _sourceKeys.length &&
                          _sourceKeys[i] == ds.name,
                      onTap: () => setState(() => _sourceKeys[i] = ds.name),
                    )),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF45866),
                ),
                onPressed: () {
                  context.read<DashboardModel>().updateWidget(
                    widget.config.copyWith(
                      data: {
                        'type': _type,
                        'visualizerKey': _visualizerKey,
                        'sourceKeys': List<String>.from(
                          _sourceKeys.whereType<String>(),
                        ),
                      },
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
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
        color: selected ? const Color(0xFFF45866) : Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Colors.white54),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}
