import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/models/telemetry_quality.dart';
import 'package:rudertelemetrie_mobile_app/providers/bluetooth_provider.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

class TelemetryQualityIndicator extends StatelessWidget {
  const TelemetryQualityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = context
        .read<BluetoothProviderModel>()
        .manager
        .telemetryQuality;

    return AnimatedBuilder(
      animation: monitor,
      builder: (context, _) {
        final quality = monitor.quality;
        final appearance = _appearanceFor(quality);

        return Semantics(
          liveRegion: true,
          label: appearance.label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: appearance.color.withValues(alpha: 0.14),
              border: Border.all(
                color: appearance.color.withValues(alpha: 0.65),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(appearance.icon, color: appearance.color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appearance.label,
                    style: TextStyle(
                      color: appearance.color,
                      fontSize: AppTypeScale.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _QualityAppearance _appearanceFor(TelemetryQuality quality) {
    return switch (quality.level) {
      TelemetryQualityLevel.waiting => const _QualityAppearance(
        color: AppPalette.faintLabel,
        icon: Icons.sensors,
        label: 'Waiting for force and angle data',
      ),
      TelemetryQualityLevel.live => const _QualityAppearance(
        color: AppPalette.ok,
        icon: Icons.check_circle_outline,
        label: 'Sensor data live',
      ),
      TelemetryQualityLevel.delayed => _QualityAppearance(
        color: AppPalette.warning,
        icon: Icons.warning_amber_rounded,
        label: _delayLabel(quality),
      ),
      TelemetryQualityLevel.interrupted => _QualityAppearance(
        color: AppPalette.danger,
        icon: Icons.signal_wifi_statusbar_connected_no_internet_4,
        label: 'No sensor data for ${_formatSilence(quality.silence)}',
      ),
    };
  }

  String _delayLabel(TelemetryQuality quality) {
    final missing = quality.missingPackets;
    if (missing > 0) {
      return 'Packet loss: $missing ${missing == 1 ? 'packet' : 'packets'} missing';
    }
    if (quality.invalidPackets > 0) {
      return 'Incomplete sensor data received';
    }
    return 'Sensor data delayed (${_formatSilence(quality.silence)})';
  }

  String _formatSilence(Duration? silence) {
    if (silence == null) return '–';
    return '${(silence.inMilliseconds / 1000).toStringAsFixed(1)} s';
  }
}

class _QualityAppearance {
  final Color color;
  final IconData icon;
  final String label;

  const _QualityAppearance({
    required this.color,
    required this.icon,
    required this.label,
  });
}
