import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/utils/format.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Record/stop/reset control with live elapsed + distance, for the dashboard
/// header. Phase 0 is manual-only.
class SessionControl extends StatelessWidget {
  const SessionControl({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<RecordingSession>();
    final recording = session.isRecording;
    final hasData = session.state != SessionState.idle;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasData) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatElapsed(session.elapsed),
                style: const TextStyle(
                  color: AppPalette.label,
                  fontSize: AppTypeScale.label,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                formatDistance(session.distanceMeters),
                style: const TextStyle(
                  color: AppPalette.faintLabel,
                  fontSize: AppTypeScale.caption,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        // Dimmed when a detected catch would not start anything, so the user
        // can tell whether auto-start is currently armed.
        Semantics(
          label: recording ? 'Stop recording' : 'Start recording',
          button: true,
          child: _CircleButton(
            icon: recording ? Icons.stop : Icons.fiber_manual_record,
            color: recording || session.isAutoArmed
                ? AppPalette.accent
                : AppPalette.accent.withAlpha(110),
            onTap: recording ? session.stop : session.start,
          ),
        ),
        if (hasData && !recording) ...[
          const SizedBox(width: 4),
          Semantics(
            label: 'Discard recording',
            button: true,
            child: _CircleButton(
              icon: Icons.refresh,
              color: AppPalette.faintLabel,
              onTap: session.reset,
            ),
          ),
        ],
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: kMinTapTarget,
      height: kMinTapTarget,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
  );
}
