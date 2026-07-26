import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/derived/session_reducer_sources.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

import 'dashboard_model.dart';
import 'param_field.dart';
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
  Map<String, double> _params = {};
  Reduction _reduction = Reduction.raw;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visualizers = context.read<VisualizerProviderModel>().registry.all;
    if (_visualizerKey == null && visualizers.isNotEmpty) {
      _visualizerKey = visualizers.first.name;
      _sourceKeys = List.filled(visualizers.first.sourceCount, null);
      _params = _defaultParams(visualizers.first);
    }
  }

  AnyVisualizer? get _selectedVisualizer {
    if (_visualizerKey == null) return null;
    return context.read<VisualizerProviderModel>().registry.get(_visualizerKey!);
  }

  bool get _canAdd =>
      _visualizerKey != null && _sourceKeys.every((k) => k != null);

  Map<String, double> _defaultParams(AnyVisualizer v) => {
    for (final p in v.params) p.key: p.defaultValue,
  };

  void _selectVisualizer(AnyVisualizer v) {
    setState(() {
      _visualizerKey = v.name;
      _sourceKeys = List.filled(v.sourceCount, null);
      _params = _defaultParams(v);
    });
  }

  Map<String, List<DataSource>> _groupSources(List<DataSource> sources) {
    final grouped = <String, List<DataSource>>{};
    for (final ds in sources) {
      (grouped[ds.group ?? 'Other'] ??= []).add(ds);
    }
    return grouped;
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
          'sourceKeys': _effectiveSourceKeys(context),
          'params': Map<String, double>.from(_params),
        },
      ),
    );
    Navigator.pop(context);
  }

  /// Instrument tiles (gauge/level) bypass the visualizer pipeline and just
  /// carry their source keys.
  void _addSimple(BuildContext context, String type, List<String> keys, int w, int h) {
    context.read<DashboardModel>().addWidget(
      WidgetConfig(
        id: 'w_${DateTime.now().millisecondsSinceEpoch}',
        x: 0,
        y: 0,
        w: w,
        h: h,
        data: {'type': type, 'sourceKeys': keys},
      ),
    );
    Navigator.pop(context);
  }

  void _addGauge(BuildContext context) {
    final keys = _sourceKeys.whereType<String>().toList();
    if (keys.isEmpty) return;
    _addSimple(context, 'gauge', [keys.first], 2, 2);
  }

  /// Resolves the selected source keys, wrapping a single source in a registered
  /// reducer when the user picked an average/peak reduction.
  List<String> _effectiveSourceKeys(BuildContext context) {
    final keys = List<String>.from(_sourceKeys.whereType<String>());
    if (_reduction == Reduction.raw || keys.length != 1) return keys;

    final registry = context.read<DataSourceProviderModel>().registry;
    final base = registry.get(keys.first);
    if (base == null) return keys;

    final reduced = reducedSource(base, _reduction, context.read<RecordingSession>());
    if (reduced == null) return keys;
    final existing = registry.get(reduced.name);
    if (existing != null) {
      reduced.dispose();
      return [existing.name];
    }
    registry.register(reduced);
    return [reduced.name];
  }

  @override
  Widget build(BuildContext context) {
    final visualizers = context.read<VisualizerProviderModel>().registry.all;
    final dataSources = context.watch<DataSourceProviderModel>().registry.all;
    final sourceCount = _selectedVisualizer?.sourceCount ?? 0;

    final hasSource = _sourceKeys.any((k) => k != null);

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
              const SizedBox(width: 8),
              Expanded(
                child: _AddButton(
                  icon: Icons.bar_chart,
                  label: 'Bar',
                  enabled: _canAdd,
                  onTap: _canAdd ? () => _add(context, 'bar', 2, 3) : null,
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
                  onTap: () => _addSimple(context, 'level', const [], 2, 2),
                ),
              ),
            ],
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

        if (_selectedVisualizer?.params.isNotEmpty ?? false) ...[
          const Text(
            'Settings',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          ..._selectedVisualizer!.params.map((p) => ParamField(
                key: ValueKey('param_${p.key}'),
                param: p,
                value: _params[p.key] ?? p.defaultValue,
                onChanged: (v) => _params[p.key] = v,
              )),
          const SizedBox(height: 16),
        ],

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
            ..._groupSources(dataSources).entries.map((group) => _SourceGroup(
                  key: ValueKey('src${i}_${group.key}'),
                  title: group.key,
                  children: group.value
                      .map((ds) => _SourceOption(
                            dataSource: ds,
                            selected: _sourceKeys[i] == ds.name,
                            onTap: () =>
                                setState(() => _sourceKeys[i] = ds.name),
                          ))
                      .toList(),
                )),
          const SizedBox(height: 12),
        ],

        if (sourceCount == 1) ...[
          const Text(
            'Reduction',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          _ReductionSelector(
            selected: _reduction,
            onChanged: (r) => setState(() => _reduction = r),
          ),
        ],
      ],
    );
  }
}

class _ReductionSelector extends StatelessWidget {
  final Reduction selected;
  final ValueChanged<Reduction> onChanged;

  const _ReductionSelector({required this.selected, required this.onChanged});

  static const _labels = {
    Reduction.raw: 'Raw',
    Reduction.average: 'Average',
    Reduction.peak: 'Peak since start',
  };

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final entry in _labels.entries) ...[
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF45866)
                    .withAlpha(selected == entry.key ? 40 : 0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected == entry.key
                      ? const Color(0xFFF45866)
                      : Colors.white24,
                ),
              ),
              child: Text(
                entry.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected == entry.key
                      ? const Color(0xFFF45866)
                      : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        if (entry.key != Reduction.peak) const SizedBox(width: 6),
      ],
    ],
  );
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

class _SourceGroup extends StatefulWidget {
  final String title;
  final List<Widget> children;

  const _SourceGroup({
    super.key,
    required this.title,
    required this.children,
  });

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
