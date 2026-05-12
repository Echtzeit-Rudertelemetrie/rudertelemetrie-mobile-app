import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_transformer.dart';

/// Live numeric readout for a registered stream.
class ValueTile extends StatefulWidget {
  final DataSource dataSource;
  final DataTransformer dataTransformer;

  const ValueTile({
    super.key,
    required this.dataSource,
    required this.dataTransformer,
  });

  @override
  State<ValueTile> createState() => _ValueTileState();
}

class _ValueTileState extends State<ValueTile> {
  static const _updateInterval = Duration(milliseconds: 500);

  StreamSubscription<List<FlSpot>>? _sub;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  var _latest = 0.0;

  @override
  void initState() {
    super.initState();

    resubscribe();
  }

  @override
  void didUpdateWidget(ValueTile old) {
    super.didUpdateWidget(old);
    if (old.dataSource != widget.dataSource ||
        old.dataTransformer != widget.dataTransformer) {
      resubscribe();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void resubscribe() {
    _sub?.cancel();
    _sub = widget.dataSource.data
        .transform(widget.dataTransformer.transformer)
        .listen((spots) {
          final now = DateTime.now();
          if (now.difference(_lastUpdate) < _updateInterval) return;
          _lastUpdate = now;
          setState(() => _latest = spots.first.y);
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
              widget.dataSource.name,
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
              widget.dataSource.unit.toString(),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
