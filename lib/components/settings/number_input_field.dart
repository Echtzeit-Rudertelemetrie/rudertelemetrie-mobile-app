import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Returns why [candidate] is unacceptable, or null when it is fine.
typedef NumberValidator = String? Function(double candidate);

/// Numeric setup field shared by the rig and stroke-detection screens.
///
/// Three things it does that a bare [TextField] does not:
/// * follows [value] when it changes underneath — a config that loads
///   asynchronously must not leave the field showing a stale default that the
///   next keystroke writes back;
/// * refuses to commit a value [validate] rejects, showing the reason inline
///   rather than letting an impossible rig silently unregister every source;
/// * debounces the commit, so typing `0.88` writes the config once, not
///   four times.
///
/// A null [value] means "nothing stored yet": the field shows [placeholder] as
/// a hint rather than a number that looks saved but is not.
class NumberInputField extends StatefulWidget {
  static const _accent = AppPalette.accent;

  final String label;
  final String unit;
  final double? value;
  final String? placeholder;
  final ValueChanged<double> onCommitted;
  final NumberValidator? validate;
  final Duration debounce;

  const NumberInputField({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.onCommitted,
    this.placeholder,
    this.validate,
    this.debounce = const Duration(milliseconds: 400),
  });

  @override
  State<NumberInputField> createState() => _NumberInputFieldState();
}

class _NumberInputFieldState extends State<NumberInputField> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );
  final FocusNode _focusNode = FocusNode();

  Timer? _pending;
  String? _error;

  static String _format(double? v) => v == null
      ? ''
      : v == v.roundToDouble()
      ? v.toInt().toString()
      : '$v';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(NumberInputField old) {
    super.didUpdateWidget(old);
    if (widget.value == old.value) return;
    // Leave the text alone while it already parses to the incoming value —
    // rewriting it mid-edit would fight the user's cursor.
    if (_parsed(_controller.text) == widget.value) return;
    _controller.value = TextEditingValue(
      text: _format(widget.value),
      selection: TextSelection.collapsed(offset: _format(widget.value).length),
    );
    setState(() => _error = null);
  }

  @override
  void dispose() {
    _pending?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  double? _parsed(String raw) => double.tryParse(raw.replaceAll(',', '.'));

  void _onChanged(String raw) {
    _pending?.cancel();
    final parsed = _parsed(raw);
    if (parsed == null) {
      setState(() => _error = raw.isEmpty ? null : 'Enter a number');
      return;
    }

    final error = widget.validate?.call(parsed);
    setState(() => _error = error);
    if (error != null) return;

    _pending = Timer(widget.debounce, () => widget.onCommitted(parsed));
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) return;
    _commitNow();
  }

  void _commitNow() {
    _pending?.cancel();
    final parsed = _parsed(_controller.text);
    if (parsed == null || widget.validate?.call(parsed) != null) return;
    if (parsed == widget.value) return;
    widget.onCommitted(parsed);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label,
        style: const TextStyle(color: AppPalette.faintLabel, fontSize: 12),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(child: _field()),
          const SizedBox(width: 6),
          Text(
            widget.unit,
            style: const TextStyle(color: AppPalette.faintLabel, fontSize: 13),
          ),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: 4),
        Text(
          _error!,
          style: const TextStyle(
            color: AppPalette.danger,
            fontSize: AppTypeScale.caption,
          ),
        ),
      ],
    ],
  );

  Widget _field() => TextField(
    controller: _controller,
    focusNode: _focusNode,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    style: const TextStyle(color: AppPalette.label, fontSize: 14),
    cursorColor: NumberInputField._accent,
    decoration: InputDecoration(
      isDense: true,
      hintText: widget.placeholder,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: AppPalette.gridLine,
      enabledBorder: _border(
        _error == null ? AppPalette.outline : AppPalette.danger,
      ),
      focusedBorder: _border(
        _error == null ? NumberInputField._accent : AppPalette.danger,
      ),
    ),
    onChanged: _onChanged,
    onSubmitted: (_) => _commitNow(),
  );

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );
}
