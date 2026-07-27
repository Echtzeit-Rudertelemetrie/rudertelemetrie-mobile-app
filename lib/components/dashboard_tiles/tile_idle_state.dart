import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// What a tile shows before its first point arrives.
///
/// A gated pipeline (per-stroke source, drive-gated curve, session reducer) can
/// stay legitimately empty for minutes while everything upstream is healthy. A
/// blank tile or a spinner that never resolves reads as a broken binding, so
/// when the binding knows what it is waiting for it says so instead.
class TileIdleState extends StatelessWidget {
  final String? hint;

  const TileIdleState({super.key, required this.hint});

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    if (hint == null) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppPalette.accent,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, size: 16, color: Colors.white24),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: AppTypeScale.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
