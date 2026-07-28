import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// How a [StatusRow] reads at a glance: settled, needs attention, or simply
/// not set up yet. Only the colour of the badge changes — the row still says
/// in words what the state is.
enum StatusTone { ok, warning, neutral }

extension on StatusTone {
  Color get color => switch (this) {
    StatusTone.ok => AppPalette.ok,
    StatusTone.warning => AppPalette.warning,
    StatusTone.neutral => AppPalette.faintLabel,
  };

  IconData get icon => switch (this) {
    StatusTone.ok => FIcons.check,
    StatusTone.warning => FIcons.triangleAlert,
    StatusTone.neutral => FIcons.minus,
  };
}

/// One line of a [StatusCard]: what is being reported, and how it currently
/// stands. With [onTap] the row leads to the screen that fixes it.
class StatusRow extends StatelessWidget {
  final String title;
  final String value;
  final StatusTone tone;
  final VoidCallback? onTap;

  const StatusRow({
    super.key,
    required this.title,
    required this.value,
    required this.tone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      constraints: const BoxConstraints(minHeight: kMinTapTarget),
      alignment: Alignment.center,
      child: Row(
        children: [
          _Badge(tone: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppPalette.label,
                fontSize: AppTypeScale.body,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: tone == StatusTone.warning
                  ? AppPalette.warning
                  : AppPalette.mutedLabel,
              fontSize: AppTypeScale.label,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(
              FIcons.chevronRight,
              size: 16,
              color: AppPalette.disabledLabel,
            ),
          ],
        ],
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final StatusTone tone;

  const _Badge({required this.tone});

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      color: tone.color.withAlpha(40),
      shape: BoxShape.circle,
    ),
    child: Icon(tone.icon, size: 14, color: tone.color),
  );
}

/// A titled panel of [StatusRow]s, divided by hairlines.
class StatusCard extends StatelessWidget {
  final String title;
  final List<StatusRow> rows;

  const StatusCard({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      border: Border.all(color: AppPalette.surfaceBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppPalette.label,
            fontSize: AppTypeScale.body,
            fontWeight: FontWeight.w700,
          ),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppPalette.gridLine),
          rows[i],
        ],
      ],
    ),
  );
}
