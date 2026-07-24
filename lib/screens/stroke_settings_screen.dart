import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_settings.dart';

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
      child: ListView(
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
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 16),
          if (settings.mode == ThresholdMode.absolute) ...[
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    key: const ValueKey('fOn'),
                    label: 'Catch force F_on',
                    value: settings.fOn,
                    onChanged: (v) => settings.setAbsoluteThresholds(fOn: v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    key: const ValueKey('fOff'),
                    label: 'Finish force F_off',
                    value: settings.fOff,
                    onChanged: (v) => settings.setAbsoluteThresholds(fOff: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
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
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
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

  static const _accent = Color(0xFFF45866);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final entry in options.entries) ...[
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _accent.withAlpha(value == entry.key ? 40 : 0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: value == entry.key ? _accent : Colors.white24,
                ),
              ),
              child: Text(
                entry.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: value == entry.key ? _accent : Colors.white70,
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

class _NumberField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));

  static String _format(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : '$v';

  void _handleChanged(String raw) {
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed != null && parsed >= 0) widget.onChanged(parsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: const Color(0xFFF45866),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white10,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFF45866)),
                ),
              ),
              onChanged: _handleChanged,
            ),
          ),
          const SizedBox(width: 6),
          const Text('N', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    ],
  );
}
