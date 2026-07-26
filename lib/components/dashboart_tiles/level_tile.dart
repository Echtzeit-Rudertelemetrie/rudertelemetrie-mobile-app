import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/kinematics/level_reading.dart';

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
  final LowPass _fx = LowPass(0.4);
  final LowPass _fy = LowPass(0.4);
  final LowPass _fz = LowPass(0.4);
  final List<StreamSubscription<Measurement>> _subs = [];
  DateTime? _lastX, _lastY, _lastZ;

  double _surge = 0;
  LevelReading _reading =
      const LevelReading(roll: 0, pitch: 0, gravity: 9.81);
  late final Ticker _ticker;
  var _dirty = false;

  @override
  void initState() {
    super.initState();
    _bind();
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
    for (final s in _subs) {
      s.cancel();
    }
    _ticker.dispose();
    super.dispose();
  }

  DataSource? _find(String prefix) {
    for (final s in widget.registry.all) {
      if (s.name.startsWith(prefix)) return s;
    }
    return null;
  }

  void _bind() {
    final x = _find('Acceleration X');
    final y = _find('Acceleration Y');
    final z = _find('Acceleration Z');
    if (x == null || y == null || z == null) return;

    _subs.add(x.data.listen((m) {
      _surge = m.value;
      _fx.add(m.value, _dt(m.timestamp, _lastX));
      _lastX = m.timestamp;
      _recompute();
    }));
    _subs.add(y.data.listen((m) {
      _fy.add(m.value, _dt(m.timestamp, _lastY));
      _lastY = m.timestamp;
      _recompute();
    }));
    _subs.add(z.data.listen((m) {
      _fz.add(m.value, _dt(m.timestamp, _lastZ));
      _lastZ = m.timestamp;
      _recompute();
    }));
  }

  double _dt(DateTime now, DateTime? last) =>
      last == null ? 0 : now.difference(last).inMicroseconds / 1e6;

  void _recompute() {
    _reading = LevelReading.fromAccel(_fx.value, _fy.value, _fz.value);
    _dirty = true;
  }

  bool get _hasSources => _subs.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasSources) {
      return const Center(
        child: Text(
          'No boat IMU',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }
    if (!_reading.isGravityReferenced) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Accel not gravity-referenced\n(|g| off) — level unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.amber, fontSize: 11),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Level',
                  style: TextStyle(color: Colors.white54, fontSize: 10)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('SIM',
                    style: TextStyle(color: Colors.white38, fontSize: 8)),
              ),
            ],
          ),
          Expanded(
            child: CustomPaint(
              painter: _LevelPainter(reading: _reading, surge: _surge),
              size: Size.infinite,
            ),
          ),
          Text(
            'roll ${_reading.rollDegrees.toStringAsFixed(0)}°  '
            'pitch ${_reading.pitchDegrees.toStringAsFixed(0)}°',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  static const _accent = Color(0xFFF45866);
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
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), ring);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), ring);

    // Bubble: roll -> x, pitch -> y (bow up = pitch positive moves bubble up).
    final nx = (reading.roll / _maxTiltRad).clamp(-1.0, 1.0);
    final ny = (reading.pitch / _maxTiltRad).clamp(-1.0, 1.0);
    final bubble = Offset(
      center.dx + nx * radius,
      center.dy - ny * radius,
    );
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
