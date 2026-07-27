import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_settings.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// When a session starts and stops by itself, and how short a session has to be
/// before it is treated as an accident rather than training.
class RecordingSettingsScreen extends StatelessWidget {
  const RecordingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<RecordingSettings>();

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Recording'),
        prefixes: [
          FHeaderAction(
            icon: const Icon(FIcons.arrowLeft),
            onPress: () => Navigator.pop(context),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          children: [
            FTileGroup(
              children: [
                FTile(
                  title: const Text('Auto-start on detected rowing'),
                  subtitle: const Text(
                    'Off means only the record button starts a session.',
                  ),
                  suffix: FSwitch(
                    value: settings.autoStart,
                    onChange: settings.setAutoStart,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SecondsSlider(
              label: 'Auto-stop after no strokes',
              value: settings.autoStopIdle,
              range: RecordingSettings.autoStopIdleRange,
              onChanged: settings.setAutoStopIdle,
              enabled: settings.autoStart,
            ),
            const SizedBox(height: 20),
            _SecondsSlider(
              label: 'Discard sessions shorter than',
              value: settings.minimumDuration,
              range: RecordingSettings.minimumDurationRange,
              onChanged: settings.setMinimumDuration,
            ),
            const SizedBox(height: 8),
            const Text(
              'Short recordings are usually the boat being carried or an '
              'oarlock being tested, not training.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondsSlider extends StatelessWidget {
  final String label;
  final Duration value;
  final ({int min, int max}) range;
  final ValueChanged<Duration> onChanged;
  final bool enabled;

  const _SecondsSlider({
    required this.label,
    required this.value,
    required this.range,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final muted = enabled ? Colors.white54 : Colors.white24;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flexible so a large system text scale wraps the label instead of
            // overflowing the row.
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: muted, fontSize: AppTypeScale.label),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${value.inSeconds} s',
              style: TextStyle(
                color: enabled ? AppPalette.label : AppPalette.disabledLabel,
                fontSize: AppTypeScale.label,
              ),
            ),
          ],
        ),
        Slider(
          value: value.inSeconds.toDouble(),
          min: range.min.toDouble(),
          max: range.max.toDouble(),
          divisions: range.max - range.min,
          activeColor: AppPalette.accent,
          onChanged: enabled
              ? (v) => onChanged(Duration(seconds: v.round()))
              : null,
        ),
      ],
    );
  }
}
