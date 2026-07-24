import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';

/// Formats a session duration as `h:mm:ss`.
String formatElapsed(Duration d) {
  final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '${d.inHours}:$minutes:$seconds';
}

/// Formats a distance in metres as `m` below 1 km, else `km` with two decimals.
String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(2)} km';

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
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                formatDistance(session.distanceMeters),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        _CircleButton(
          icon: recording ? Icons.stop : Icons.fiber_manual_record,
          color: const Color(0xFFF45866),
          onTap: recording ? session.stop : session.start,
        ),
        if (hasData && !recording) ...[
          const SizedBox(width: 4),
          _CircleButton(
            icon: Icons.refresh,
            color: Colors.white54,
            onTap: session.reset,
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
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
  );
}
