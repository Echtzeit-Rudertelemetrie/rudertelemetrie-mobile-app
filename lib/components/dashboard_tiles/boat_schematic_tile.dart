import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/dashboard_tiles/tile_idle_state.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/source_binder.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_layout.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oarlocks.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Boat schematic Tier 2 (widget-boat-schematic): a stylised hull from above
/// (bow up) with each oar drawn at its live θ, placed by [BoatConfig]. Bypasses
/// the visualizer pipeline and subscribes to the `Angle N` sources directly; θ
/// is tweened toward the latest sample each frame for fluid motion.
class BoatSchematicTile extends StatefulWidget {
  final DataSourceRegistry registry;

  const BoatSchematicTile({super.key, required this.registry});

  @override
  State<BoatSchematicTile> createState() => _BoatSchematicTileState();
}

class _BoatSchematicTileState extends State<BoatSchematicTile>
    with SingleTickerProviderStateMixin {
  final Map<String, double> _target = {};
  final Map<String, double> _current = {};
  late final SourceBinder _binder;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _binder = SourceBinder(widget.registry);
    _ticker = createTicker(_onFrame)..start();
  }

  @override
  void dispose() {
    _binder.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _onFrame(Duration _) {
    var changed = false;
    for (final key in _target.keys) {
      final cur = _current[key] ?? _target[key]!;
      final next = cur + (_target[key]! - cur) * 0.25;
      if ((next - cur).abs() > 0.05) changed = true;
      _current[key] = next;
    }
    if (changed && mounted) setState(() {});
  }

  void _ensureSubscribed(String oarlockKey) {
    if (_binder.isBound(oarlockKey)) return;
    _binder.bind(
      oarlockKey,
      matches: byGroupAndPrefix(oarlockKey, 'Angle '),
      onData: (m) => _target[oarlockKey] = m.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<BoatConfig>();
    final keys = connectedOarlockKeys(widget.registry).toList();
    for (final key in keys) {
      _ensureSubscribed(key);
    }
    final placements = computeBoatLayout(
      boatClass: config.boatClass,
      slots: config.slots,
      oarlockKeys: keys,
    );

    if (placements.isEmpty) {
      return const TileIdleState(label: 'Boat', hint: 'No oarlocks connected');
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child: CustomPaint(
        painter: _BoatPainter(
          seats: config.boatClass.seats,
          placements: placements,
          angles: {
            for (final p in placements)
              p.oarlockKey:
                  _current[p.oarlockKey] ?? _target[p.oarlockKey] ?? 0,
          },
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _BoatPainter extends CustomPainter {
  static const _accent = AppPalette.accent;

  final int seats;
  final List<OarPlacement> placements;
  final Map<String, double> angles;

  _BoatPainter({
    required this.seats,
    required this.placements,
    required this.angles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hullWidth = size.width * 0.16;
    final cx = size.width / 2;

    // Hull: rounded vertical capsule, bow (pointed) at top.
    final hull = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, size.height / 2),
        width: hullWidth,
        height: size.height * 0.86,
      ),
      Radius.circular(hullWidth / 2),
    );
    canvas.drawRRect(
      hull,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white30,
    );
    // Bow marker.
    canvas.drawCircle(
      Offset(cx, size.height * 0.08),
      2.5,
      Paint()..color = Colors.white54,
    );

    final oarLength = size.width * 0.30;
    for (final p in placements) {
      final y = _seatY(p.seat, size.height);
      final theta = (angles[p.oarlockKey] ?? 0) * math.pi / 180;
      for (final sign in _sides(p.side)) {
        final pin = Offset(cx + sign * hullWidth / 2, y);
        // θ=0 → straight out to the side; +θ (bow) rotates toward the top.
        final dir = Offset(sign * math.cos(theta), -math.sin(theta));
        canvas.drawLine(
          pin,
          pin + dir * oarLength,
          Paint()
            ..color = _accent
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(pin, 2, Paint()..color = Colors.white);
      }
    }
  }

  double _seatY(int seat, double height) {
    if (seats <= 1) return height / 2;
    final frac = (seat - 1) / (seats - 1);
    return height * (0.2 + 0.6 * frac); // seat 1 (bow) near top
  }

  List<double> _sides(OarSide side) => switch (side) {
    OarSide.port => const [-1],
    OarSide.starboard => const [1],
    OarSide.both => const [-1, 1],
  };

  @override
  bool shouldRepaint(_BoatPainter old) => true;
}
