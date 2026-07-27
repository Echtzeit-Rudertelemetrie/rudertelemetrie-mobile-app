import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rudertelemetrie_mobile_app/components/dashboard_tiles/tile_idle_state.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/source_binder.dart';
import 'package:rudertelemetrie_mobile_app/services/kinematics/level_reading.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Spirit-level + surge indicator (widget-level-acceleration spec). Bypasses the
/// visualizer pipeline and subscribes to the boat `Acceleration X/Y/Z` sources
/// directly. Roll/pitch come from a heavily low-passed gravity vector; the surge
/// arrow tracks the unfiltered longitudinal `a_x`.
class LevelTile extends StatefulWidget {
  final DataSourceRegistry registry;

  const LevelTile({super.key, required this.registry});

  @override
  State<LevelTile> createState() => _LevelTileState();
}

class _LevelTileState extends State<LevelTile>
    with SingleTickerProviderStateMixin {
  static const _title = 'Level';
  static const _axes = ['X', 'Y', 'Z'];

  late final SourceBinder _binder;
  late final Ticker _ticker;

  var _filters = _AxisFilters();
  double _surge = 0;
  LevelReading _reading = const LevelReading(roll: 0, pitch: 0, gravity: 9.81);
  var _dirty = false;

  @override
  void initState() {
    super.initState();
    _binder = SourceBinder(widget.registry, onChanged: _onSourcesChanged);
    for (final axis in _axes) {
      _binder.bind(
        axis,
        matches: byNamePrefix('Acceleration $axis'),
        onData: (m) => _onSample(axis, m),
      );
    }
    _ticker = createTicker((_) {
      if (_dirty) {
        _dirty = false;
        setState(() {});
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _binder.dispose();
    _ticker.dispose();
    super.dispose();
  }

  /// A disconnect must return the tile to its empty state, not freeze it on the
  /// last reading, so the filters start over whenever the axis set changes.
  void _onSourcesChanged() {
    if (!mounted) return;
    setState(() {
      _filters = _AxisFilters();
      _surge = 0;
      _reading = const LevelReading(roll: 0, pitch: 0, gravity: 9.81);
    });
  }

  void _onSample(String axis, Measurement m) {
    if (axis == 'X') _surge = m.value;
    _filters.add(axis, m);
    _reading = _filters.reading;
    _dirty = true;
  }

  bool get _hasSources => _axes.every(_binder.isBound);

  @override
  Widget build(BuildContext context) {
    if (!_hasSources) {
      return const TileIdleState(label: _title, hint: 'No boat IMU');
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            _title,
            style: TextStyle(
              color: Colors.white54,
              fontSize: AppTypeScale.caption,
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (!_reading.isGravityReferenced) {
      return const Center(
        child: Text(
          'Accel not gravity-referenced\n(|g| off) — level unavailable',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.amber, fontSize: AppTypeScale.caption),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _LevelPainter(reading: _reading, surge: _surge),
            size: Size.infinite,
          ),
        ),
        Text(
          'roll ${_reading.rollDegrees.toStringAsFixed(0)}°  '
          'pitch ${_reading.pitchDegrees.toStringAsFixed(0)}°',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: AppTypeScale.caption,
          ),
        ),
      ],
    );
  }
}

/// One low-pass per acceleration axis, sample-rate independent via the gap
/// between consecutive timestamps on that axis.
class _AxisFilters {
  final Map<String, LowPass> _filters = {
    for (final axis in ['X', 'Y', 'Z']) axis: LowPass(0.4),
  };
  final Map<String, DateTime> _last = {};

  void add(String axis, Measurement m) {
    _filters[axis]!.add(m.value, _dt(axis, m.timestamp));
    _last[axis] = m.timestamp;
  }

  double _dt(String axis, DateTime now) {
    final last = _last[axis];
    return last == null ? 0 : now.difference(last).inMicroseconds / 1e6;
  }

  LevelReading get reading => LevelReading.fromAccel(
    _filters['X']!.value,
    _filters['Y']!.value,
    _filters['Z']!.value,
  );
}

class _LevelPainter extends CustomPainter {
  static const _accent = AppPalette.accent;
  static const _maxTiltRad = math.pi / 6; // ±30° maps to the rim

  final LevelReading reading;
  final double surge;

  _LevelPainter({required this.reading, required this.surge});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white24;
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(center, radius / 2, ring..color = Colors.white10);
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      ring,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      ring,
    );

    // Bubble: roll -> x, pitch -> y (bow up = pitch positive moves bubble up).
    final nx = (reading.roll / _maxTiltRad).clamp(-1.0, 1.0);
    final ny = (reading.pitch / _maxTiltRad).clamp(-1.0, 1.0);
    final bubble = Offset(center.dx + nx * radius, center.dy - ny * radius);
    final level = nx.abs() < 0.12 && ny.abs() < 0.12;
    canvas.drawCircle(
      bubble,
      7,
      Paint()..color = level ? Colors.greenAccent : Colors.amber,
    );

    // Surge arrow: horizontal, length tracks a_x (±5 m/s² full scale).
    final surgeN = (surge / 5).clamp(-1.0, 1.0);
    final arrowEnd = Offset(center.dx + surgeN * radius, center.dy);
    canvas.drawLine(
      center,
      arrowEnd,
      Paint()
        ..color = _accent
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LevelPainter old) =>
      old.reading != reading || old.surge != surge;
}
