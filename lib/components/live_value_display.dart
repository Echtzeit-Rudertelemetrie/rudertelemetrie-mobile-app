import 'dart:async';

import 'package:flutter/material.dart';

class LiveValueDisplay extends StatefulWidget {
  final Stream<double> signal;
  final String label;
  final String unit;
  final int decimalPlaces;

  const LiveValueDisplay({
    super.key,
    required this.signal,
    required this.label,
    this.unit = '',
    this.decimalPlaces = 1,
  });

  @override
  State<LiveValueDisplay> createState() => _LiveValueDisplayState();
}

class _LiveValueDisplayState extends State<LiveValueDisplay> {
  late final StreamSubscription<double> _subscription;
  double? _value;

  @override
  void initState() {
    super.initState();
    _subscription = widget.signal.listen((v) => setState(() => _value = v));
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final display = _value == null
        ? '—'
        : '${_value!.toStringAsFixed(widget.decimalPlaces)}${widget.unit}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(widget.label, style: textTheme.labelSmall),
        Text(display, style: textTheme.headlineMedium),
      ],
    );
  }
}
