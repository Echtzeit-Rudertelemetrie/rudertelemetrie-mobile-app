import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'stream_registry.dart';
import 'widget_config.dart';

/// Renders a live data tile whose stream and display style are read from
/// [config.data]:
///
/// ```dart
/// config.data['type']      // 'chart' | 'value'  (default: 'value')
/// config.data['streamKey'] // key into StreamRegistry
/// ```
///
/// In edit mode, tapping the tile calls [onTap] (e.g. to open a configure sheet).
class TileContent extends StatefulWidget {
  final WidgetConfig config;
  final bool editMode;
  final VoidCallback? onTap;

  const TileContent({
    super.key,
    required this.config,
    required this.editMode,
    this.onTap,
  });

  @override
  State<TileContent> createState() => _TileContentState();
}

class _TileContentState extends State<TileContent>
    with SingleTickerProviderStateMixin {
  static const double _windowSeconds = 8.0;
  static const int _maxPoints = 300;

  late Ticker _ticker;
  StreamSubscription<double>? _sub;
  StreamInfo? _info;

  final _spots = <FlSpot>[];
  final _stopwatch = Stopwatch()..start();
  double? _latest;

  String? get _streamKey => widget.config.data['streamKey'] as String?;
  String get _type => widget.config.data['type'] as String? ?? 'value';

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) { if (mounted) setState(() {}); })..start();
    _resubscribe();
  }

  @override
  void didUpdateWidget(TileContent old) {
    super.didUpdateWidget(old);
    final oldKey = old.config.data['streamKey'] as String?;
    if (oldKey != _streamKey) _resubscribe();
  }

  void _resubscribe() {
    _sub?.cancel();
    _spots.clear();
    _latest = null;
    _info = _streamKey != null ? StreamRegistry.get(_streamKey!) : null;
    if (_info == null) return;
    _sub = _info!.stream.listen((v) {
      _latest = v;
      final t = _stopwatch.elapsed.inMicroseconds / 1e6;
      _spots.add(FlSpot(t, v));
      final cutoff = t - _windowSeconds;
      while (_spots.isNotEmpty && _spots.first.x < cutoff) {
        _spots.removeAt(0);
      }
      if (_spots.length > _maxPoints) {
        _spots.removeRange(0, _spots.length - _maxPoints);
      }
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

    if (info == null) {
      return GestureDetector(
        onTap: widget.editMode ? widget.onTap : null,
        child: _NoStreamPlaceholder(editMode: widget.editMode),
      );
    }

    return GestureDetector(
      onTap: widget.editMode ? widget.onTap : null,
      child: _type == 'chart' ? _buildChart(info) : _buildValue(info),
    );
  }

  // ---------------------------------------------------------------------------
  // Chart
  // ---------------------------------------------------------------------------

  Widget _buildChart(StreamInfo info) {
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

  // ---------------------------------------------------------------------------
  // Value
  // ---------------------------------------------------------------------------

  Widget _buildValue(StreamInfo info) {
    final value = _latest;
    final display = value == null
        ? '—'
        : value.abs() >= 100
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(info.label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(display,
                style: const TextStyle(
                    color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          ),
          if (info.unit.isNotEmpty)
            Text(info.unit, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _NoStreamPlaceholder extends StatelessWidget {
  final bool editMode;
  const _NoStreamPlaceholder({required this.editMode});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_chart, color: Colors.white24, size: 28),
        if (editMode) ...[
          const SizedBox(height: 6),
          const Text('Tap to configure',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ],
    ),
  );
}
