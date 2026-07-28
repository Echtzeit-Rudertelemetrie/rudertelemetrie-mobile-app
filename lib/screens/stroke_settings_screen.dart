import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/settings/number_input_field.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_settings.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Stroke-detection settings (stroke-engine §Parameters): threshold mode with
/// absolute thresholds, and crew aggregation.
class StrokeSettingsScreen extends StatelessWidget {
  const StrokeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<StrokeSettings>();

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Stroke Detection'),
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
          padding: EdgeInsets.zero,
          children: [
            const _Label('Threshold mode'),
            _Segmented<ThresholdMode>(
              value: settings.mode,
              options: const {
                ThresholdMode.absolute: 'Absolute',
                ThresholdMode.autoScaled: 'Auto-scaled',
              },
              onChanged: settings.setMode,
            ),
            const SizedBox(height: 6),
            Text(
              settings.mode == ThresholdMode.absolute
                  ? 'Fixed catch/finish forces.'
                  : 'Thresholds scale with recent peak force (k·F_peak).',
              style: const TextStyle(
                color: AppPalette.disabledLabel,
                fontSize: AppTypeScale.caption,
              ),
            ),
            const SizedBox(height: 16),
            if (settings.mode == ThresholdMode.absolute) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: NumberInputField(
                      key: const ValueKey('fOn'),
                      label: 'Catch force F_on',
                      unit: 'N',
                      value: settings.fOn,
                      validate: (v) => _validateCatchForce(v, settings.fOff),
                      onCommitted: (v) =>
                          settings.setAbsoluteThresholds(fOn: v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NumberInputField(
                      key: const ValueKey('fOff'),
                      label: 'Finish force F_off',
                      unit: 'N',
                      value: settings.fOff,
                      validate: (v) => _validateFinishForce(v, settings.fOn),
                      onCommitted: (v) =>
                          settings.setAbsoluteThresholds(fOff: v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            const _Label('Catch rise rate'),
            NumberInputField(
              key: const ValueKey('forceRateOn'),
              label: 'Minimum dF/dt for a catch',
              unit: 'N/s',
              value: settings.forceRateOn,
              validate: _validateForceRate,
              onCommitted: settings.setForceRateOn,
            ),
            const SizedBox(height: 6),
            const Text(
              'Applies in both modes. Sensor drift is thousands of times slower '
              'than a catch, so this is what stops a drifted signal from '
              'crossing the catch force on its own. Lower it only if gentle '
              'paddling goes undetected.',
              style: TextStyle(
                color: AppPalette.disabledLabel,
                fontSize: AppTypeScale.caption,
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Crew aggregation'),
            _Segmented<CrewAggregation>(
              value: settings.crewAggregation,
              options: const {
                CrewAggregation.max: 'All reached (max)',
                CrewAggregation.mean: 'Mean',
              },
              onChanged: settings.setCrewAggregation,
            ),
          ],
        ),
      ),
    );
  }
}

/// The detector needs hysteresis: a finish threshold at or above the catch
/// threshold would latch a stroke on and never end it.
String? _validateCatchForce(double value, double finishForce) {
  if (value <= 0) return 'Must be greater than 0';
  if (value <= finishForce) return 'Must exceed F_off ($finishForce N)';
  return null;
}

/// Zero would disable the gate entirely and hand drift the catch back.
String? _validateForceRate(double value) =>
    value <= 0 ? 'Must be greater than 0' : null;

String? _validateFinishForce(double value, double catchForce) {
  if (value < 0) return 'Cannot be negative';
  if (value >= catchForce) return 'Must be below F_on ($catchForce N)';
  return null;
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(color: AppPalette.faintLabel, fontSize: 12),
    ),
  );
}

class _Segmented<T> extends StatelessWidget {
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  static const _accent = AppPalette.accent;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final entry in options.entries) ...[
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(entry.key),
            child: Container(
              constraints: const BoxConstraints(minHeight: kMinTapTarget),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _accent.withAlpha(value == entry.key ? 40 : 0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: value == entry.key ? _accent : AppPalette.outline,
                ),
              ),
              child: Text(
                entry.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: value == entry.key ? _accent : AppPalette.mutedLabel,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        if (entry.key != options.keys.last) const SizedBox(width: 6),
      ],
    ],
  );
}
