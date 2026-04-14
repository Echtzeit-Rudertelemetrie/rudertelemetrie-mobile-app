import 'dart:async';

import 'package:flutter/material.dart';

import 'stream_registry.dart';

/// Live numeric readout for a registered stream.
class ValueTile extends StatefulWidget {
  final String streamKey;

  const ValueTile({super.key, required this.streamKey});

  @override
  State<ValueTile> createState() => _ValueTileState();
}

class _ValueTileState extends State<ValueTile> {
  StreamSubscription<double>? _sub;
  StreamInfo? _info;
  double? _latest;

  @override
  void initState() {
    super.initState();
    _resubscribe();
  }

  @override
  void didUpdateWidget(ValueTile old) {
    super.didUpdateWidget(old);
    if (old.streamKey != widget.streamKey) _resubscribe();
  }

  void _resubscribe() {
    _sub?.cancel();
    _latest = null;
    _info = StreamRegistry.get(widget.streamKey);
    if (_info == null) return;
    _sub = _info!.stream.listen((v) {
      if (mounted) setState(() => _latest = v);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) return const SizedBox.shrink();

    final value = _latest;
    final display = value == null
        ? '—'
        : value.abs() >= 100
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(display,
                style: const TextStyle(
                    color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
            if (info.unit.isNotEmpty)
              Text(info.unit, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
