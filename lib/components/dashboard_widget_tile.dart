import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_config.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_registry.dart';
import 'package:rudertelemetrie_mobile_app/models/dashboard_model.dart';

/// A single tile on the dashboard. Handles drag and resize in edit mode.
class DashboardWidgetTile extends StatefulWidget {
  final WidgetConfig config;
  final double cellWidth;
  final double cellHeight;

  /// Called continuously while dragging so the grid can show a ghost.
  final void Function(int ghostX, int ghostY)? onDragUpdate;
  final VoidCallback? onDragEnd;

  /// Called continuously while resizing so the grid can show a ghost.
  final void Function(int ghostW, int ghostH)? onResizeUpdate;
  final VoidCallback? onResizeEnd;

  const DashboardWidgetTile({
    super.key,
    required this.config,
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
  // Drag state
  Offset _dragAccum = Offset.zero;

  // Resize state
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
        // Content — fills the tile, no gesture on it while in edit mode
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1a1d30),
              borderRadius: BorderRadius.circular(8),
              border: editMode
                  ? Border.all(color: const Color(0xFFF45866), width: 1.5)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: WidgetRegistry.build(context, cfg),
            ),
          ),
        ),

        // Edit mode overlay
        if (editMode) ...[
          // Drag handle — top-left; pan here drives the whole tile drag
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
              onPanStart: _onDragStart,
              onPanUpdate: _onDragUpdate,
              onPanEnd: _onDragEnd,
              child: _Handle(
                icon: Icons.drag_indicator,
                color: const Color(0xFFF45866),
              ),
            ),
          ),

          // Delete button — top-right
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => context.read<DashboardModel>().removeWidget(cfg.id),
              child: _Handle(icon: Icons.close, color: Colors.redAccent),
            ),
          ),

          // Resize handle — bottom-right
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onPanStart: _onResizeStart,
              onPanUpdate: _onResizeUpdate,
              onPanEnd: _onResizeEnd,
              child: const _ResizeHandle(),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Drag handlers
  // ---------------------------------------------------------------------------

  void _onDragStart(DragStartDetails _) {
    _dragAccum = Offset.zero;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragAccum += details.delta;
    final newX = (widget.config.x + _dragAccum.dx / widget.cellWidth)
        .round()
        .clamp(0, context.read<DashboardModel>().cols - widget.config.w);
    final newY = (widget.config.y + _dragAccum.dy / widget.cellHeight)
        .round()
        .clamp(0, context.read<DashboardModel>().rows - widget.config.h);
    widget.onDragUpdate?.call(newX, newY);
  }

  void _onDragEnd(DragEndDetails _) {
    final newX = (widget.config.x + _dragAccum.dx / widget.cellWidth)
        .round()
        .clamp(0, context.read<DashboardModel>().cols - widget.config.w);
    final newY = (widget.config.y + _dragAccum.dy / widget.cellHeight)
        .round()
        .clamp(0, context.read<DashboardModel>().rows - widget.config.h);
    context.read<DashboardModel>().moveWidget(widget.config.id, newX, newY);
    _dragAccum = Offset.zero;
    widget.onDragEnd?.call();
  }

  // ---------------------------------------------------------------------------
  // Resize handlers
  // ---------------------------------------------------------------------------

  void _onResizeStart(DragStartDetails _) {
    _resizeWAccum = 0;
    _resizeHAccum = 0;
  }

  void _onResizeUpdate(DragUpdateDetails details) {
    _resizeWAccum += details.delta.dx;
    _resizeHAccum += details.delta.dy;
    final ghostW = (widget.config.w + (_resizeWAccum / widget.cellWidth).round())
        .clamp(1, 99);
    final ghostH = (widget.config.h + (_resizeHAccum / widget.cellHeight).round())
        .clamp(1, 99);
    widget.onResizeUpdate?.call(ghostW, ghostH);
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
// Helper widgets
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
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Icon(icon, size: 18, color: color),
  );
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle();

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TrianglePainter(),
    size: const Size(32, 32),
  );
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFF45866);
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter _) => false;
}
