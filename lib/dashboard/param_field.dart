import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer_param.dart';

/// A labelled numeric input for a single [VisualizerParam]. Reports clamped
/// values through [onChanged] as the user types.
class ParamField extends StatefulWidget {
  final VisualizerParam param;
  final double value;
  final ValueChanged<double> onChanged;

  const ParamField({
    super.key,
    required this.param,
    required this.value,
    required this.onChanged,
  });

  @override
  State<ParamField> createState() => _ParamFieldState();
}

class _ParamFieldState extends State<ParamField> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));

  static String _format(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  void _handleChanged(String raw) {
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed == null) return;
    widget.onChanged(widget.param.clamp(parsed));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.param.label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _input()),
            if (widget.param.unitLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                widget.param.unitLabel!,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _input() => TextField(
    controller: _controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
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
  );
}
