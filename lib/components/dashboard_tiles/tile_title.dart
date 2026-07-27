import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// The header line of a plotting tile: what it plots, from which source, in
/// which units.
///
/// Two tiles running the same visualizer over different oarlocks are otherwise
/// indistinguishable, so [source] is on the line as well — and it takes the
/// slack, because it is the part that can be arbitrarily long.
class TileTitle extends StatelessWidget {
  final String label;
  final String? source;
  final String units;

  const TileTitle({
    super.key,
    required this.label,
    required this.source,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final source = this.source;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.faintLabel,
              fontSize: AppTypeScale.caption,
            ),
          ),
          if (source != null) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                source,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppPalette.disabledLabel,
                  fontSize: AppTypeScale.caption,
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          Text(
            units,
            style: const TextStyle(
              color: AppPalette.disabledLabel,
              fontSize: AppTypeScale.caption,
            ),
          ),
        ],
      ),
    );
  }
}
