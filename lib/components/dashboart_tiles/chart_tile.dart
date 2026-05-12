import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
                  widget.dataTransformer.yUnit.toString(),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: widget.fixedXRange != null
                    ? _spots.last.x - widget.fixedXRange!.inMilliseconds
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
