import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/force_angle_source_pair.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Radio marker shared by every source picker in the configuration sheets.
class SelectionRadio extends StatelessWidget {
  final bool selected;

  const SelectionRadio({super.key, required this.selected});

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? AppPalette.accent : AppPalette.disabledLabel,
        width: 2,
      ),
    ),
    child: selected
        ? const Center(
            child: CircleAvatar(radius: 5, backgroundColor: AppPalette.accent),
          )
        : null,
  );
}

/// Picks one oarlock instead of two loose streams. A force/angle curve is only
/// meaningful when both axes come from the same oarlock, so the pair is chosen
/// as a unit and bound as X = angle, Y = force.
class ForceAnglePicker extends StatelessWidget {
  final List<DataSource> sources;
  final List<String?> selectedKeys;
  final ValueChanged<List<String>> onChanged;

  const ForceAnglePicker({
    super.key,
    required this.sources,
    required this.selectedKeys,
    required this.onChanged,
  });

  bool _isSelected(ForceAngleSourcePair pair) =>
      selectedKeys.length == 2 &&
      selectedKeys[0] == pair.angle.name &&
      selectedKeys[1] == pair.force.name;

  @override
  Widget build(BuildContext context) {
    final pairs = forceAngleSourcePairs(sources);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Oarlock (X: angle, Y: force)',
          style: TextStyle(
            color: AppPalette.faintLabel,
            fontSize: AppTypeScale.caption,
          ),
        ),
        const SizedBox(height: 4),
        if (pairs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No oarlock with force and angle data available.',
              style: TextStyle(color: AppPalette.disabledLabel),
            ),
          )
        else
          ...pairs.map(
            (pair) => _PairOption(
              pair: pair,
              selected: _isSelected(pair),
              onTap: () => onChanged(pair.sourceKeys),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _PairOption extends StatelessWidget {
  final ForceAngleSourcePair pair;
  final bool selected;
  final VoidCallback onTap;

  const _PairOption({
    required this.pair,
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
                pair.label,
                style: const TextStyle(
                  color: AppPalette.label,
                  fontSize: AppTypeScale.body,
                ),
              ),
              Text(
                '${pair.angle.unit.label} / ${pair.force.unit.label}',
                style: const TextStyle(
                  color: AppPalette.faintLabel,
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
