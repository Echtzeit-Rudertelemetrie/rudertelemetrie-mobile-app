import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/source_requirement.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

import 'force_angle_picker.dart';

/// One selectable row: a radio, what the thing is called, and a line saying
/// what it is. [trailing] carries a unit or other short qualifier.
class OptionRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;
  final String? trailing;

  const OptionRow({
    super.key,
    required this.selected,
    required this.onTap,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      constraints: const BoxConstraints(minHeight: kMinTapTarget),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SelectionRadio(selected: selected),
          ),
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
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppPalette.faintLabel,
                      fontSize: AppTypeScale.caption,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: const TextStyle(
                color: AppPalette.faintLabel,
                fontSize: AppTypeScale.caption,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Picks one data source, grouped by the device that produces it.
///
/// Sources the app derives from a pick the user already made — the session
/// reducers behind Average / Peak — are left out: they are an option on a
/// source, not a source of their own, and listing them doubles the list every
/// time somebody adds an averaged tile.
class SourcePicker extends StatelessWidget {
  final List<DataSource> sources;
  final String? selectedKey;
  final ValueChanged<String> onSelected;

  /// Narrows the list to the sources this slot can actually use.
  final SourceRequirement requirement;

  /// Keeps the collapse state of two pickers shown at once (the X and the Y
  /// axis of a two-source visualizer) from being shared.
  final String slot;

  const SourcePicker({
    super.key,
    required this.sources,
    required this.selectedKey,
    required this.onSelected,
    this.requirement = SourceRequirement.any,
    this.slot = '',
  });

  @override
  Widget build(BuildContext context) {
    final groups = _grouped();
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          requirement.emptyMessage,
          style: const TextStyle(color: AppPalette.disabledLabel),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups.entries)
          _SourceGroup(
            key: ValueKey('$slot/${group.key}'),
            title: group.key,
            children: [
              for (final source in group.value)
                OptionRow(
                  selected: selectedKey == source.name,
                  onTap: () => onSelected(source.name),
                  title: source.info.label,
                  subtitle: source.info.description,
                  trailing: source.unit.label,
                ),
            ],
          ),
      ],
    );
  }

  Map<String, List<DataSource>> _grouped() {
    final grouped = <String, List<DataSource>>{};
    for (final source in sources) {
      if (source.derived || !requirement.accepts(source)) continue;
      (grouped[source.group ?? 'Other'] ??= []).add(source);
    }
    return grouped;
  }
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
