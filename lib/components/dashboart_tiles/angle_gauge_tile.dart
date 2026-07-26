import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

/// Live scull-angle dial (boat-schematic Tier 1). Bypasses the visualizer
/// pipeline and subscribes to an `Angle N` source directly, showing the current
/// θ (0 = perpendicular, + toward the bow) with the running catch/finish
/// extremes marked.
class AngleGaugeTile extends StatefulWidget {
  final DataSource source;

  const AngleGaugeTile({super.key, required this.source});

  @override
  State<AngleGaugeTile> createState() => _AngleGaugeTileState();
}

class _AngleGaugeTileState extends State<AngleGaugeTile>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Measurement>? _sub;
  late final Ticker _ticker;
  var _dirty = false;

  double _angle = 0;
  double? _catchAngle; // running max (toward bow)
  double? _finishAngle; // running min (toward stern)

  @override
  void initState() {
    super.initState();
    _subscribe();
    _ticker = createTicker((_) {
      if (_dirty) {
        _dirty = false;
        setState(() {});
      }
    });
    _ticker.start();
  }

  @override
  void didUpdateWidget(AngleGaugeTile old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _subscribe() {
    _sub?.cancel();
    _catchAngle = null;
    _finishAngle = null;
    _sub = widget.source.data.listen((m) {
      _angle = m.value;
      _catchAngle = _catchAngle == null ? m.value : math.max(_catchAngle!, m.value);
      _finishAngle =
          _finishAngle == null ? m.value : math.min(_finishAngle!, m.value);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      children: [
        Text(
          widget.source.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        Expanded(
          child: CustomPaint(
            painter: _GaugePainter(
              angle: _angle,
              catchAngle: _catchAngle,
              finishAngle: _finishAngle,
            ),
            size: Size.infinite,
          ),
        ),
        Text(
          '${_angle.toStringAsFixed(0)}°',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _GaugePainter extends CustomPainter {
  static const _accent = Color(0xFFF45866);

  /// Half-span of the dial: ±[_span]° maps to the arc edges.
  static const double _span = 90;

  final double angle;
  final double? catchAngle;
  final double? finishAngle;

  _GaugePainter({
    required this.angle,
    required this.catchAngle,
    required this.finishAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height * 0.9);
    final radius = math.min(size.width / 2, size.height * 0.8) - 4;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white24;
    // Semicircle opening upward: sweep from 180° to 360°.
    canvas.drawArc(
      Rect.fromCircle(center: pivot, radius: radius),
      math.pi,
      math.pi,
      false,
      arc,
    );

    void needle(double deg, Color color, double width, double lengthFactor) {
      final a = (deg / _span).clamp(-1.0, 1.0) * (math.pi / 2);
      // θ=0 straight up; +θ (bow) to the right.
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(
        pivot,
        pivot + dir * (radius * lengthFactor),
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    if (finishAngle != null) needle(finishAngle!, Colors.white24, 2, 0.95);
    if (catchAngle != null) needle(catchAngle!, Colors.white38, 2, 0.95);
    needle(angle, _accent, 3, 1.0);
    canvas.drawCircle(pivot, 3, Paint()..color = _accent);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.angle != angle ||
      old.catchAngle != catchAngle ||
      old.finishAngle != finishAngle;
}
