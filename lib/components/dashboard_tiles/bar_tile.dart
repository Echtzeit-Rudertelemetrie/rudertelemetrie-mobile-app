import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rudertelemetrie_mobile_app/components/dashboard_tiles/tile_idle_state.dart';
import 'package:rudertelemetrie_mobile_app/components/dashboard_tiles/tile_title.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';
import 'package:rudertelemetrie_mobile_app/services/visualization/visualizer.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';
import 'package:rudertelemetrie_mobile_app/theme/chart_style.dart';

/// One bar per stroke for a per-stroke source. Consumes the same
/// [BoundVisualizer] pipeline as [ChartTile]; the newest bar is highlighted.
class BarTile extends StatefulWidget {
  final BoundVisualizer visualizer;

  const BarTile({super.key, required this.visualizer});

  @override
  State<BarTile> createState() => _BarTileState();
}

class _BarTileState extends State<BarTile> with SingleTickerProviderStateMixin {
  static const _accent = AppPalette.accent;

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
  void didUpdateWidget(BarTile old) {
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

  double get _maxY {
    var maxV = 0.0;
    for (final p in _points) {
      maxV = max(maxV, p.y);
    }
    if (maxV <= 0) return 1;
    final magnitude = pow(10, (log(maxV) / ln10).floor()).toDouble();
    final rounded = (maxV / magnitude).ceilToDouble() * magnitude;
    return rounded <= maxV ? rounded + magnitude : rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (_points.isEmpty) {
      return TileIdleState(
        label: widget.visualizer.name,
        hint: widget.visualizer.idleHint ?? 'No strokes detected yet.',
        source: widget.visualizer.sourceLabel,
      );
    }

    final maxY = _maxY;
    final groups = <BarChartGroupData>[
      for (var i = 0; i < _points.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: _points[i].y,
              width: 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
              color: i == _points.length - 1 ? _accent : _accent.withAlpha(110),
            ),
          ],
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TileTitle(
            label: widget.visualizer.name,
            source: widget.visualizer.sourceLabel,
            units: widget.visualizer.units.y.label,
          ),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barGroups: groups,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _format(value),
                            style: chartAxisLabelStyle,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 16,
                      getTitlesWidget: (value, meta) =>
                          _bottomLabel(value.toInt()),
                    ),
                  ),
                ),
                gridData: chartGridData(maxY / 4),
                borderData: chartBorderData,
                barTouchData: BarTouchData(enabled: false),
              ),
              duration: Duration.zero,
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom axis labels: the stroke index carried in each point's x, thinned so
  /// only a few show.
  Widget _bottomLabel(int barIndex) {
    if (barIndex < 0 || barIndex >= _points.length) {
      return const SizedBox.shrink();
    }
    final step = (_points.length / 4).ceil();
    if (barIndex % step != 0 && barIndex != _points.length - 1) {
      return const SizedBox.shrink();
    }
    return Text(
      _points[barIndex].x.toInt().toString(),
      style: chartAxisLabelStyle,
    );
  }

  String _format(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}
