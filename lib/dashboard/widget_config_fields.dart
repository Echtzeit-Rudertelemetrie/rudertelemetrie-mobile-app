import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/derived/session_reducer_sources.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

import 'force_angle_picker.dart';
import 'param_field.dart';
import 'widget_config_draft.dart';

/// The visualizer / settings / sources / reduction editor, shared by the add
/// and configure sheets so both offer the same options.
///
/// Edits land in [draft] directly; [onChanged] is the host sheet's `setState`.
class WidgetConfigFields extends StatelessWidget {
  final WidgetConfigDraft draft;
  final List<AnyVisualizer> visualizers;
  final AnyVisualizer? selected;
  final List<DataSource> dataSources;
  final VoidCallback onChanged;

  const WidgetConfigFields({
    super.key,
    required this.draft,
    required this.visualizers,
    required this.selected,
    required this.dataSources,
    required this.onChanged,
  });

  void _edit(void Function() change) {
    change();
    onChanged();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SectionLabel('Visualizer'),
      const SizedBox(height: 4),
      ...visualizers.map(
        (v) => _VisualizerOption(
          visualizer: v,
          selected: draft.visualizerKey == v.name,
          onTap: () => _edit(() => draft.selectVisualizer(v)),
        ),
      ),
      const SizedBox(height: 16),
      ..._settings(),
      ..._sources(),
      ..._reduction(),
    ],
  );

  List<Widget> _settings() {
    final params = selected?.params ?? const [];
    if (params.isEmpty) return const [];

    return [
      const _SectionLabel('Settings'),
      const SizedBox(height: 4),
      ...params.map(
        (p) => ParamField(
          key: ValueKey('param_${p.key}'),
          param: p,
          value: draft.params[p.key] ?? p.defaultValue,
          onChanged: (v) => draft.params[p.key] = v,
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _sources() {
    if (selected?.sourceSelectionMode == SourceSelectionMode.forceAnglePair) {
      return [
        ForceAnglePicker(
          sources: dataSources,
          selectedKeys: draft.sourceKeys,
          onChanged: (keys) => _edit(() => draft.sourceKeys = [...keys]),
        ),
      ];
    }

    return [
      for (int i = 0; i < (selected?.sourceCount ?? 0); i++) ...[
        _SectionLabel(_sourceLabel(i)),
        const SizedBox(height: 4),
        ..._sourcePicker(i),
        const SizedBox(height: 12),
      ],
    ];
  }

  String _sourceLabel(int index) {
    if (selected?.sourceCount == 1) return 'Data source';
    return index == 0 ? 'X axis' : 'Y axis';
  }

  List<Widget> _sourcePicker(int index) {
    if (dataSources.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No streams available.',
            style: TextStyle(color: AppPalette.disabledLabel),
          ),
        ),
      ];
    }

    return _groupSources(dataSources).entries
        .map(
          (group) => _SourceGroup(
            key: ValueKey('src${index}_${group.key}'),
            title: group.key,
            children: group.value
                .map(
                  (ds) => _SourceOption(
                    dataSource: ds,
                    selected:
                        index < draft.sourceKeys.length &&
                        draft.sourceKeys[index] == ds.name,
                    onTap: () =>
                        _edit(() => draft.sourceKeys[index] = ds.name),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  List<Widget> _reduction() {
    if (!draft.offersReduction(selected)) return const [];

    return [
      const _SectionLabel('Reduction'),
      const SizedBox(height: 4),
      _ReductionSelector(
        selected: draft.reduction,
        onChanged: (r) => _edit(() => draft.reduction = r),
      ),
    ];
  }

  Map<String, List<DataSource>> _groupSources(List<DataSource> sources) {
    final grouped = <String, List<DataSource>>{};
    for (final ds in sources) {
      (grouped[ds.group ?? 'Other'] ??= []).add(ds);
    }
    return grouped;
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppPalette.faintLabel,
      fontSize: AppTypeScale.caption,
    ),
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
  Widget build(BuildContext context) => _OptionRow(
    selected: selected,
    onTap: onTap,
    title: visualizer.name,
    subtitle:
        '${visualizer.sourceCount} source${visualizer.sourceCount == 1 ? '' : 's'}',
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
  Widget build(BuildContext context) => _OptionRow(
    selected: selected,
    onTap: onTap,
    title: dataSource.name,
    subtitle: dataSource.unit.label,
  );
}

class _OptionRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  const _OptionRow({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SelectionRadio(selected: selected),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppPalette.label,
                    fontSize: AppTypeScale.body,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppPalette.faintLabel,
                    fontSize: AppTypeScale.caption,
                  ),
                ),
              ],
            ),
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
                color: AppPalette.faintLabel,
              ),
              const SizedBox(width: 4),
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppPalette.label,
                  fontSize: AppTypeScale.label,
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
                color: AppPalette.accent.withAlpha(
                  selected == entry.key ? 40 : 0,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected == entry.key
                      ? AppPalette.accent
                      : AppPalette.outline,
                ),
              ),
              child: Text(
                entry.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected == entry.key
                      ? AppPalette.accent
                      : AppPalette.mutedLabel,
                  fontSize: AppTypeScale.caption,
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
