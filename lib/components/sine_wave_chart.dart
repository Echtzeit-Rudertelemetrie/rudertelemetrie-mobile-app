import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class SineWaveChart extends StatefulWidget {
  final Stream<double> signal;

  const SineWaveChart({super.key, required this.signal});

  @override
  State<SineWaveChart> createState() => _SineWaveChartState();
}

class _SineWaveChartState extends State<SineWaveChart>
    with SingleTickerProviderStateMixin {
  static const double _windowSeconds = 2.0;
  static const int _maxPoints = 480;

  late final Ticker _renderTicker;
  late final StreamSubscription<double> _subscription;
  final Stopwatch _stopwatch = Stopwatch()..start();
  final List<FlSpot> _spots = [];

  @override
  void initState() {
    super.initState();
    _subscription = widget.signal.listen(_onSample);
    _renderTicker = createTicker((_) => setState(() {}))..start();
  }

  void _onSample(double value) {
    final t = _stopwatch.elapsed.inMicroseconds / 1e6;
    _spots.add(FlSpot(t, value));

    final cutoff = t - _windowSeconds;
    while (_spots.isNotEmpty && _spots.first.x < cutoff) {
      _spots.removeAt(0);
    }

    if (_spots.length > _maxPoints) {
      _spots.removeRange(0, _spots.length - _maxPoints);
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _renderTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          LineChartBarData(
            spots: _spots,
            isCurved: false,
            dotData: const FlDotData(show: false),
            barWidth: 1.5,
            color: Theme.of(context).colorScheme.primary,
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
