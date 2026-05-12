import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

/// Live numeric readout showing the latest y-value from a [BoundVisualizer].
class ValueTile extends StatefulWidget {
  final BoundVisualizer visualizer;

  const ValueTile({super.key, required this.visualizer});

  @override
  State<ValueTile> createState() => _ValueTileState();
}

class _ValueTileState extends State<ValueTile> {
  static const _updateInterval = Duration(milliseconds: 500);

  StreamSubscription<List<XYPoint>>? _sub;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  var _latest = 0.0;

  @override
  void initState() {
    super.initState();
    _resubscribe();
  }

  @override
  void didUpdateWidget(ValueTile old) {
    super.didUpdateWidget(old);
    if (old.visualizer != widget.visualizer) _resubscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _resubscribe() {
    _sub?.cancel();
    _sub = widget.visualizer.output.listen((points) {
      final now = DateTime.now();
      if (now.difference(_lastUpdate) < _updateInterval) return;
      _lastUpdate = now;
      setState(() => _latest = points.last.y);
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = _latest;
    final display = value.abs() >= 100
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.visualizer.name,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              display,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.visualizer.units.y.name,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
