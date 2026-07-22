import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';

class ChartTile extends StatefulWidget {
  final BoundVisualizer visualizer;

  const ChartTile({super.key, required this.visualizer});

  @override
  State<ChartTile> createState() => _ChartTileState();
}

class _ChartTileState extends State<ChartTile>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  StreamSubscription<List<XYPoint>>? _sub;

  var _points = <XYPoint>[];
  var _dirty = false;

  @override
  void initState() {
    super.initState();
    _resubscribe();
    _ticker = createTicker((_) {
      if (_dirty) {
        _dirty = false;
        setState(() {});
      }
    });
    _ticker.start();
  }

  @override
  void didUpdateWidget(ChartTile old) {
    super.didUpdateWidget(old);
    if (old.visualizer != widget.visualizer) _resubscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _resubscribe() {
    _sub?.cancel();
    _points = [];
    _sub = widget.visualizer.output.listen((points) {
      _points = points;
      _dirty = true;
    });
  }

  /// X-axis bounds fitted to the actual data range. Unlike the Y axis this does
  /// not anchor to zero: value-vs-value trajectories have a non-monotonic X, so
  /// bounds come straight from the min/max of the points.
  ({double min, double max, double interval}) get _xAxis {
    var dataMin = _points.first.x;
    var dataMax = _points.first.x;
    for (final p in _points) {
      dataMin = min(dataMin, p.x);
      dataMax = max(dataMax, p.x);
    }
    final interval = _niceInterval((dataMax - dataMin) / 5);
    return (min: dataMin, max: dataMax, interval: interval);
  }

  double _niceInterval(double raw) {
    if (raw <= 0) return 1;
    final exp = (log(raw) / ln10).floor();
    final magnitude = pow(10, exp).toDouble();
    final fraction = raw / magnitude;
    if (fraction <= 1) return magnitude;
    if (fraction <= 2) return 2 * magnitude;
    if (fraction <= 5) return 5 * magnitude;
    return 10 * magnitude;
  }

  String _xLabel(double value) => '${_formatNumber(value)}${widget.visualizer.units.x.name}';

  String _yLabel(double value) => '${_formatNumber(value)}${widget.visualizer.units.y.name}';

  String _formatNumber(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

  /// Y-axis bounds fitted to the current data: the top rounds up to a nice
  /// value above the highest point, and the bottom follows negative data
  /// (otherwise it stays at zero).
  ({double min, double max, double interval}) get _yAxis {
    var dataMin = _points.first.y;
    var dataMax = _points.first.y;
    for (final p in _points) {
      dataMin = min(dataMin, p.y);
      dataMax = max(dataMax, p.y);
    }

    final lower = dataMin < 0 ? dataMin : 0.0;
    final interval = _niceInterval((dataMax - lower) / 4);

    var maxY = (dataMax / interval).ceilToDouble() * interval;
    if (maxY <= dataMax) maxY += interval;

    var minY = 0.0;
    if (lower < 0) {
      minY = (lower / interval).floorToDouble() * interval;
      if (minY >= lower) minY -= interval;
    }

    return (min: minY, max: maxY, interval: interval);
  }

  @override
  Widget build(BuildContext context) {
    if (_points.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFF45866),
          ),
        ),
      );
    }

    final spots = _points.map((p) => FlSpot(p.x, p.y)).toList();
    final yAxis = _yAxis;
    final xAxis = _xAxis;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Row(
              children: [
                Text(
                  widget.visualizer.name,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.visualizer.units.y.name} / ${widget.visualizer.units.x.name}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: xAxis.min,
                maxX: xAxis.max,
                minY: yAxis.min,
                maxY: yAxis.max,
                clipData: const FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFFF45866),
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: yAxis.interval,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _yLabel(value),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 8,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      interval: xAxis.interval,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          space: 2,
                          child: Text(
                            _xLabel(value),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 8,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yAxis.interval,
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
