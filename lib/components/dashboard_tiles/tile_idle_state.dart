import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// What a tile shows before its first point arrives.
///
/// A gated pipeline (per-stroke source, drive-gated curve, session reducer) can
/// stay legitimately empty for minutes while everything upstream is healthy. A
/// blank tile or a spinner that never resolves reads as a broken binding, so
/// the tile keeps naming itself through [label] and [source] and, when the
/// binding knows what it is waiting for, says so through [hint].
class TileIdleState extends StatelessWidget {
  final String label;
  final String? hint;

  /// The data source(s) the tile reads. Null for a tile bound to fixed
  /// hardware rather than a source the user picked.
  final String? source;

  const TileIdleState({
    super.key,
    required this.label,
    required this.hint,
    this.source,
  });

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    final source = this.source;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppPalette.faintLabel,
                  fontSize: AppTypeScale.caption,
                ),
              ),
              if (source != null) ...[
                const SizedBox(height: 2),
                Text(
                  source,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.disabledLabel,
                    fontSize: AppTypeScale.caption,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              _indicator(),
              if (hint != null) ...[
                const SizedBox(height: 6),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.disabledLabel,
                    fontSize: AppTypeScale.caption,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _indicator() => hint == null
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppPalette.accent,
          ),
        )
      : const Icon(Icons.hourglass_empty, size: 16, color: AppPalette.outline);
}
