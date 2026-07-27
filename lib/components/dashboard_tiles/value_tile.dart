import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/components/dashboard_tiles/tile_idle_state.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';
import 'package:rudertelemetrie_mobile_app/utils/format.dart';

/// Live numeric readout showing the latest y-value from a [BoundVisualizer].
class ValueTile extends StatefulWidget {
  final BoundVisualizer visualizer;

  const ValueTile({super.key, required this.visualizer});

  @override
  State<ValueTile> createState() => _ValueTileState();
}

class _ValueTileState extends State<ValueTile> {
  static const _updateInterval = Duration(milliseconds: 500);

  /// After this long without a sample the number on screen is history, not a
  /// reading — a frozen source must not look like a steady one.
  static const _staleAfter = Duration(seconds: 6);

  StreamSubscription<List<XYPoint>>? _sub;
  Timer? _staleTimer;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastSample;

  /// Distinguishes "has read zero" from "has never read anything" — the latter
  /// is not a measurement and must not be displayed as one.
  var _received = false;
  var _latest = 0.0;

  @override
  void initState() {
    super.initState();
    _resubscribe();
    _staleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isStale) setState(() {});
    });
  }

  @override
  void didUpdateWidget(ValueTile old) {
    super.didUpdateWidget(old);
    if (old.visualizer != widget.visualizer) _resubscribe();
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  bool get _isStale {
    final last = _lastSample;
    return last == null || DateTime.now().difference(last) > _staleAfter;
  }

  void _resubscribe() {
    _sub?.cancel();
    _lastSample = null;
    _received = false;
    _sub = widget.visualizer.output.listen((points) {
      final now = DateTime.now();
      _lastSample = now;
      if (now.difference(_lastUpdate) < _updateInterval && _received) return;
      _lastUpdate = now;
      setState(() {
        _received = true;
        _latest = points.last.y;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_received) {
      return TileIdleState(
        label: widget.visualizer.name,
        hint: widget.visualizer.idleHint,
      );
    }

    final value = _latest;
    final unit = widget.visualizer.units.y;
    final display = switch (unit) {
      Unit.pace => formatPace(value),
      _ when value.abs() >= 100 => value.toStringAsFixed(0),
      _ => value.toStringAsFixed(1),
    };
    final stale = _isStale;

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
              style: TextStyle(
                color: stale ? Colors.white38 : Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              stale ? '${unit.label} · no signal' : unit.label,
              style: TextStyle(
                color: stale ? Colors.amber : Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
