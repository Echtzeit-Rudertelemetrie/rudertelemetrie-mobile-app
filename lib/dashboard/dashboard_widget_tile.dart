import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dashboard_model.dart';
import 'widget_config.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// A single positioned tile on the dashboard grid.
///
/// The [child] widget is provided by the caller (via [DashboardGrid]'s
/// `widgetBuilder`) — the framework has no knowledge of what it contains.
///
/// In edit mode the framework adds drag / resize / delete handles on top of
/// the child.
class DashboardWidgetTile extends StatefulWidget {
  final WidgetConfig config;

  /// Pre-built content widget. Build this with your own `widgetBuilder`.
  final Widget child;

  final double cellWidth;
  final double cellHeight;

  final void Function(int ghostX, int ghostY)? onDragUpdate;
  final VoidCallback? onDragEnd;
  final void Function(int ghostW, int ghostH)? onResizeUpdate;
  final VoidCallback? onResizeEnd;

  const DashboardWidgetTile({
    super.key,
    required this.config,
    required this.child,
    required this.cellWidth,
    required this.cellHeight,
    this.onDragUpdate,
    this.onDragEnd,
    this.onResizeUpdate,
    this.onResizeEnd,
  });

  @override
  State<DashboardWidgetTile> createState() => _DashboardWidgetTileState();
}

class _DashboardWidgetTileState extends State<DashboardWidgetTile> {
  Offset _dragAccum = Offset.zero;
  double _resizeWAccum = 0;
  double _resizeHAccum = 0;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DashboardModel>();
    final editMode = model.editMode;
    final cfg = widget.config;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Content — provided entirely by the caller
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(
                color: editMode ? AppPalette.accent : AppPalette.surfaceBorder,
                width: editMode ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              child: widget.child,
            ),
          ),
        ),

        if (editMode) ...[
          // Drag handle — top-left
          Positioned(
            top: 6,
            left: 6,
            child: GestureDetector(
              onPanStart: _onDragStart,
              onPanUpdate: _onDragUpdate,
              onPanEnd: _onDragEnd,
              child: Semantics(
                label: 'Move tile',
                button: true,
                child: const _Handle(
                  icon: Icons.drag_indicator,
                  color: AppPalette.accent,
                ),
              ),
            ),
          ),

          // Delete — top-right
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => context.read<DashboardModel>().removeWidget(cfg.id),
              child: Semantics(
                label: 'Remove tile',
                button: true,
                child: const _Handle(
                  icon: Icons.close,
                  color: AppPalette.danger,
                ),
              ),
            ),
          ),

          // Resize — bottom-right
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onPanStart: _onResizeStart,
              onPanUpdate: _onResizeUpdate,
              onPanEnd: _onResizeEnd,
              child: Semantics(
                label: 'Resize tile',
                button: true,
                child: const _ResizeHandle(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Drag
  // ---------------------------------------------------------------------------

  void _onDragStart(DragStartDetails _) => _dragAccum = Offset.zero;

  void _onDragUpdate(DragUpdateDetails d) {
    _dragAccum += d.delta;
    final model = context.read<DashboardModel>();
    final cfg = widget.config;
    widget.onDragUpdate?.call(
      (cfg.x + _dragAccum.dx / widget.cellWidth).round().clamp(
        0,
        model.cols - cfg.w,
      ),
      (cfg.y + _dragAccum.dy / widget.cellHeight).round().clamp(
        0,
        model.rows - cfg.h,
      ),
    );
  }

  void _onDragEnd(DragEndDetails _) {
    final model = context.read<DashboardModel>();
    final cfg = widget.config;
    model.moveWidget(
      cfg.id,
      (cfg.x + _dragAccum.dx / widget.cellWidth).round().clamp(
        0,
        model.cols - cfg.w,
      ),
      (cfg.y + _dragAccum.dy / widget.cellHeight).round().clamp(
        0,
        model.rows - cfg.h,
      ),
    );
    _dragAccum = Offset.zero;
    widget.onDragEnd?.call();
  }

  // ---------------------------------------------------------------------------
  // Resize
  // ---------------------------------------------------------------------------

  void _onResizeStart(DragStartDetails _) {
    _resizeWAccum = 0;
    _resizeHAccum = 0;
  }

  void _onResizeUpdate(DragUpdateDetails d) {
    _resizeWAccum += d.delta.dx;
    _resizeHAccum += d.delta.dy;
    widget.onResizeUpdate?.call(
      (widget.config.w + (_resizeWAccum / widget.cellWidth).round()).clamp(
        1,
        99,
      ),
      (widget.config.h + (_resizeHAccum / widget.cellHeight).round()).clamp(
        1,
        99,
      ),
    );
  }

  void _onResizeEnd(DragEndDetails _) {
    final dw = (_resizeWAccum / widget.cellWidth).round();
    final dh = (_resizeHAccum / widget.cellHeight).round();
    if (dw != 0 || dh != 0) {
      context.read<DashboardModel>().resizeWidget(
        widget.config.id,
        (widget.config.w + dw).clamp(1, 99),
        (widget.config.h + dh).clamp(1, 99),
      );
    }
    _resizeWAccum = 0;
    _resizeHAccum = 0;
    widget.onResizeEnd?.call();
  }
}

// ---------------------------------------------------------------------------
// Internal handle widgets
// ---------------------------------------------------------------------------

class _Handle extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _Handle({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: Colors.black.withAlpha(140),
      borderRadius: BorderRadius.circular(AppRadii.control),
    ),
    child: Icon(icon, size: 18, color: color),
  );
}

/// Clipped to the tile's own corner, so the grip follows the rounded edge
/// instead of jutting a square corner past it.
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.only(
      bottomRight: Radius.circular(AppRadii.tile),
    ),
    child: CustomPaint(painter: _TrianglePainter(), size: const Size(28, 28)),
  );
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = AppPalette.accent,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter _) => false;
}
