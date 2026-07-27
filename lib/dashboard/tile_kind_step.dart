import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

import 'tile_kind.dart';

/// The first step of adding a widget: what kind of tile to place.
///
/// Each kind says in one line what it shows, and the trailing icon says what
/// happens on tap — instruments read the boat by themselves and land on the
/// dashboard straight away, the rest lead on to what they need to be told.
class TileKindStep extends StatelessWidget {
  final ValueChanged<TileKind> onSelected;

  const TileKindStep({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 20,
    children: [
      _section(
        'Data',
        'Show a stream you choose.',
        TileKind.values.where((k) => k.input != TileInput.none),
      ),
      _section(
        'Instruments',
        'Read the boat directly — nothing to configure.',
        TileKind.values.where((k) => k.input == TileInput.none),
      ),
    ],
  );

  Widget _section(String title, String caption, Iterable<TileKind> kinds) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.label,
              fontSize: AppTypeScale.label,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(
              color: AppPalette.faintLabel,
              fontSize: AppTypeScale.caption,
            ),
          ),
          const SizedBox(height: 10),
          for (final kind in kinds) ...[
            _KindCard(kind: kind, onTap: () => onSelected(kind)),
            const SizedBox(height: 8),
          ],
        ],
      );
}

class _KindCard extends StatelessWidget {
  final TileKind kind;
  final VoidCallback onTap;

  const _KindCard({required this.kind, required this.onTap});

  bool get _addsImmediately => kind.input == TileInput.none;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      constraints: const BoxConstraints(minHeight: kMinTapTarget),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.gridLine),
      ),
      child: Row(
        children: [
          _IconBadge(icon: kind.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.label,
                  style: const TextStyle(
                    color: AppPalette.label,
                    fontSize: AppTypeScale.body,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kind.description,
                  style: const TextStyle(
                    color: AppPalette.faintLabel,
                    fontSize: AppTypeScale.caption,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            _addsImmediately ? Icons.add : Icons.chevron_right,
            size: 18,
            color: AppPalette.faintLabel,
          ),
        ],
      ),
    ),
  );
}

class _IconBadge extends StatelessWidget {
  final IconData icon;

  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: AppPalette.accent.withAlpha(30),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, size: 18, color: AppPalette.accent),
  );
}
