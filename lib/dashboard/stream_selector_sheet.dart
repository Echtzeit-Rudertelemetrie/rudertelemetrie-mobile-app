import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

import 'dashboard_model.dart';
import 'force_angle_picker.dart';
import 'param_field.dart';
import 'sheet_scaffold.dart';
import 'widget_config.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

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
  late Map<String, double> _params;

  @override
  void initState() {
    super.initState();
    _type = widget.config.data['type'] as String? ?? 'value';
    _visualizerKey = widget.config.data['visualizerKey'] as String?;
    final stored = (widget.config.data['sourceKeys'] as List<dynamic>?)
        ?.cast<String>();
    _sourceKeys = stored != null ? List<String?>.from(stored) : [];
    _params = _readStoredParams(widget.config.data['params']);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSourceKeysToVisualizer();
    _syncParamsToVisualizer();
  }

  Map<String, double> _readStoredParams(dynamic raw) {
    if (raw is! Map) return {};
    final params = <String, double>{};
    raw.forEach((key, value) {
      if (value is num) params[key.toString()] = value.toDouble();
    });
    return params;
  }

  void _syncParamsToVisualizer() {
    final v = _selectedVisualizer;
    if (v == null) return;
    for (final p in v.params) {
      _params.putIfAbsent(p.key, () => p.defaultValue);
    }
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
    return context.read<VisualizerProviderModel>().registry.get(
      _visualizerKey!,
    );
  }

  void _selectVisualizer(AnyVisualizer v) {
    setState(() {
      _visualizerKey = v.name;
      _sourceKeys = List.filled(v.sourceCount, null);
      _params = {for (final p in v.params) p.key: p.defaultValue};
    });
  }

  Map<String, List<DataSource>> _groupSources(List<DataSource> sources) {
    final grouped = <String, List<DataSource>>{};
    for (final ds in sources) {
      (grouped[ds.group ?? 'Other'] ??= []).add(ds);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final visualizers = context.read<VisualizerProviderModel>().registry.all;
    final dataSources = context.watch<DataSourceProviderModel>().registry.all;
    final sourceCount = _selectedVisualizer?.sourceCount ?? 0;
    final selectsForceAnglePair =
        _selectedVisualizer?.sourceSelectionMode ==
        SourceSelectionMode.forceAnglePair;

    return SheetScaffold(
      title: 'Configure Widget',
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppPalette.accent),
          onPressed: () {
            context.read<DashboardModel>().updateWidget(
              widget.config.copyWith(
                data: {
                  'type': _type,
                  'visualizerKey': _visualizerKey,
                  'sourceKeys': List<String>.from(
                    _sourceKeys.whereType<String>(),
                  ),
                  'params': Map<String, double>.from(_params),
                },
              ),
            );
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ),
      children: [
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
        ...visualizers.map(
          (v) => _VisualizerOption(
            visualizer: v,
            selected: _visualizerKey == v.name,
            onTap: () => _selectVisualizer(v),
          ),
        ),
        const SizedBox(height: 16),

        if (_selectedVisualizer?.params.isNotEmpty ?? false) ...[
          const Text(
            'Settings',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          ..._selectedVisualizer!.params.map(
            (p) => ParamField(
              key: ValueKey('param_${p.key}'),
              param: p,
              value: _params[p.key] ?? p.defaultValue,
              onChanged: (v) => _params[p.key] = v,
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (selectsForceAnglePair)
          ForceAnglePicker(
            sources: dataSources,
            selectedKeys: _sourceKeys,
            onChanged: (keys) => setState(() => _sourceKeys = [...keys]),
          )
        else
          for (int i = 0; i < sourceCount; i++) ...[
            Text(
              sourceCount == 1
                  ? 'Data source'
                  : i == 0
                  ? 'X axis'
                  : 'Y axis',
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
              ..._groupSources(dataSources).entries.map(
                (group) => _SourceGroup(
                  key: ValueKey('src${i}_${group.key}'),
                  title: group.key,
                  children: group.value
                      .map(
                        (ds) => _SourceOption(
                          dataSource: ds,
                          selected:
                              i < _sourceKeys.length &&
                              _sourceKeys[i] == ds.name,
                          onTap: () => setState(() => _sourceKeys[i] = ds.name),
                        ),
                      )
                      .toList(),
                ),
              ),
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
          SelectionRadio(selected: selected),
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
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: AppTypeScale.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SourceGroup extends StatefulWidget {
  final String title;
  final List<Widget> children;

  const _SourceGroup({super.key, required this.title, required this.children});

  @override
  State<_SourceGroup> createState() => _SourceGroupState();
}

class _SourceGroupState extends State<_SourceGroup> {
  bool _expanded = true;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 18,
                color: Colors.white54,
              ),
              const SizedBox(width: 4),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      if (_expanded)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.children,
          ),
        ),
    ],
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
          SelectionRadio(selected: selected),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dataSource.name,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                dataSource.unit.label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: AppTypeScale.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
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
        color: selected ? AppPalette.accent : Colors.white10,
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
