import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../dashboard/stream_registry.dart';

/// Live line-chart for a registered stream.
class ChartTile extends StatefulWidget {
  final String streamKey;

  const ChartTile({super.key, required this.streamKey});

  @override
  State<ChartTile> createState() => _ChartTileState();
}

class _ChartTileState extends State<ChartTile> with SingleTickerProviderStateMixin {
  static const double _windowSeconds = 8.0;
  static const int _maxPoints = 300;

  late Ticker _ticker;
  StreamSubscription<double>? _sub;
  StreamInfo? _info;

  final _spots = <FlSpot>[];
  final _stopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) { if (mounted) setState(() {}); })..start();
    _resubscribe();
  }

  @override
  void didUpdateWidget(ChartTile old) {
    super.didUpdateWidget(old);
    if (old.streamKey != widget.streamKey) _resubscribe();
  }

  void _resubscribe() {
    _sub?.cancel();
    _spots.clear();
    _info = StreamRegistry.get(widget.streamKey);
    if (_info == null) return;
    _sub = _info!.stream.listen((v) {
      final t = _stopwatch.elapsed.inMicroseconds / 1e6;
      _spots.add(FlSpot(t, v));
      final cutoff = t - _windowSeconds;
      while (_spots.isNotEmpty && _spots.first.x < cutoff) {
        _spots.removeAt(0);
      }
      if (_spots.length > _maxPoints) _spots.removeRange(0, _spots.length - _maxPoints);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) return const SizedBox.shrink();

    if (_spots.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF45866)),
        ),
      );
    }

    final t = _stopwatch.elapsed.inMicroseconds / 1e6;
    final xMax = t < _windowSeconds ? _windowSeconds : t;
    final xMin = xMax - _windowSeconds;

    final yMin = info.minY ?? _spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 1;
    final yMax = info.maxY ?? _spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Row(
              children: [
                Text(info.label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                if (info.unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(info.unit, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ],
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: xMin,
                maxX: xMax,
                minY: yMin,
                maxY: yMax,
                clipData: const FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: _spots,
                    isCurved: false,
                    color: const Color(0xFFF45866),
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                titlesData: const FlTitlesData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.white.withAlpha(20), strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white.withAlpha(30)),
                ),
              ),
              duration: Duration.zero,
            ),
          ),
        ],
      ),
    );
  }
}
