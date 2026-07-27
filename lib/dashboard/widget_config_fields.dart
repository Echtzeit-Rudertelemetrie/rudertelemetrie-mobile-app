import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/derived/session_reducer_sources.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

import 'force_angle_picker.dart';
import 'param_field.dart';
import 'source_picker.dart';
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
        _sourcePicker(i),
        const SizedBox(height: 12),
      ],
    ];
  }

  String _sourceLabel(int index) {
    if (selected?.sourceCount == 1) return 'Data source';
    return index == 0 ? 'X axis' : 'Y axis';
  }

  Widget _sourcePicker(int index) => SourcePicker(
    slot: 'src$index',
    sources: dataSources,
    selectedKey: index < draft.sourceKeys.length
        ? draft.sourceKeys[index]
        : null,
    onSelected: (key) => _edit(() => draft.sourceKeys[index] = key),
  );

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
  Widget build(BuildContext context) => OptionRow(
    selected: selected,
    onTap: onTap,
    title: visualizer.name,
    subtitle: visualizer.description,
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
