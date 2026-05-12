import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_transformer.dart';

class ChartTile extends StatefulWidget {
  final DataSource dataSource;
  final DataTransformer dataTransformer;

  /// When set, the x-axis always spans exactly this duration ending at the
  /// latest data point (scrolling window). When null, the x-axis grows to fit
  /// all available data.
  final Duration? fixedXRange;

  const ChartTile({
    super.key,
    required this.dataSource,
    required this.dataTransformer,
    this.fixedXRange,
  });

  @override
  State<ChartTile> createState() => _ChartTileState();
}

class _ChartTileState extends State<ChartTile>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  StreamSubscription<List<FlSpot>>? _sub;

  var _spots = <FlSpot>[];
  var _dirty = false;

  @override
  void initState() {
    super.initState();

    resubscribe();

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
    if (old.dataSource != widget.dataSource ||
        old.dataTransformer != widget.dataTransformer) {
      resubscribe();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void resubscribe() {
    _sub?.cancel();

    _spots = [];

    _sub = widget.dataSource.data
        .transform(widget.dataTransformer.transformer)
        .listen((spots) {
          _spots = spots;
          _dirty = true;
        });
  }

  double get _xInterval {
    if (_spots.length < 2) return 1;
    final range = _spots.last.x - _spots.first.x;
    return _niceInterval(range / 5);
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

  String _xLabel(double value) {
    final display = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
    return '$display${widget.dataTransformer.xUnit.name}';
  }

  double _durationToXUnit(Duration d) => switch (widget.dataTransformer.xUnit) {
    Unit.ms => d.inMilliseconds.toDouble(),
    Unit.s => d.inMilliseconds / 1000.0,
    Unit.min => d.inMilliseconds / 60000.0,
    _ => d.inMilliseconds.toDouble(),
  };

  @override
  Widget build(BuildContext context) {
    if (_spots.isEmpty) {
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
                  widget.dataSource.name,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.dataTransformer.yUnit.name,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: widget.fixedXRange != null
                    ? _spots.last.x - _durationToXUnit(widget.fixedXRange!)
                    : _spots.first.x,
                maxX: _spots.last.x,
                minY: 0,
                maxY: 100,
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
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${value.toInt()}${widget.dataTransformer.yUnit.name}',
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
                      interval: _xInterval,
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
