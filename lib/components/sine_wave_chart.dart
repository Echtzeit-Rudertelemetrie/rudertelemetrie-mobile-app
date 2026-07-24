import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class SineWaveChart extends StatefulWidget {
  final List<Stream<double>> signals;

  const SineWaveChart({super.key, required this.signals});

  @override
  State<SineWaveChart> createState() => _SineWaveChartState();
}

class _SineWaveChartState extends State<SineWaveChart>
    with SingleTickerProviderStateMixin {
  static const double _windowSeconds = 2.0;
  static const int _maxPoints = 480;

  late final Ticker _renderTicker;
  late final List<StreamSubscription<double>> _subscriptions;
  final Stopwatch _stopwatch = Stopwatch()..start();
  late final List<List<FlSpot>> _spotBuffers;

  @override
  void initState() {
    super.initState();
    _spotBuffers = List.generate(widget.signals.length, (_) => []);
    _subscriptions = [
      for (final (i, stream) in widget.signals.indexed)
        stream.listen((v) => _onSample(i, v)),
    ];
    _renderTicker = createTicker((_) => setState(() {}))..start();
  }

  void _onSample(int index, double value) {
    final t = _stopwatch.elapsed.inMicroseconds / 1e6;
    final spots = _spotBuffers[index];
    spots.add(FlSpot(t, value));

    final cutoff = t - _windowSeconds;
    while (spots.isNotEmpty && spots.first.x < cutoff) {
      spots.removeAt(0);
    }

    if (spots.length > _maxPoints) {
      spots.removeRange(0, spots.length - _maxPoints);
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _renderTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = [const Color(0xFFF45866), const Color(0xFF2292A4)];

    final t = _stopwatch.elapsed.inMicroseconds / 1e6;
    final xMax = t < _windowSeconds ? _windowSeconds : t;
    final xMin = xMax - _windowSeconds;

    return LineChart(
      LineChartData(
        minX: xMin,
        maxX: xMax,
        minY: -1.2,
        maxY: 1.2,
        clipData: const FlClipData.all(),
        lineBarsData: [
          for (final (i, spots) in _spotBuffers.indexed)
            LineChartBarData(
              spots: spots,
              isCurved: false,
              dotData: const FlDotData(show: false),
              barWidth: 1.5,
              color: colors[i % colors.length],
              belowBarData: BarAreaData(show: false),
            ),
        ],
        titlesData: const FlTitlesData(show: false),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: 0.5,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Theme.of(context).colorScheme.outline.withAlpha(60),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(80),
          ),
        ),
      ),
      duration: Duration.zero,
    );
  }
}
