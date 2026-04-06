import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dashboard_model.dart';
import 'stream_selector_sheet.dart';
import 'tile_content.dart';
import 'widget_config.dart';

/// A single positioned tile on the dashboard grid.
///
/// In edit mode shows drag/resize/delete handles and makes the content
/// area tappable to open the stream selector.
class DashboardWidgetTile extends StatefulWidget {
  final WidgetConfig config;
  final double cellWidth;
  final double cellHeight;

  final void Function(int ghostX, int ghostY)? onDragUpdate;
  final VoidCallback? onDragEnd;
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
        // Content
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
              child: TileContent(
                config: cfg,
                editMode: editMode,
                onTap: editMode ? () => _showStreamSelector(context, cfg) : null,
              ),
            ),
          ),
        ),

        if (editMode) ...[
          // Drag handle — top-left
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
              onPanStart: _onDragStart,
              onPanUpdate: _onDragUpdate,
              onPanEnd: _onDragEnd,
              child: const _Handle(icon: Icons.drag_indicator, color: Color(0xFFF45866)),
            ),
          ),

          // Delete — top-right
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => context.read<DashboardModel>().removeWidget(cfg.id),
              child: const _Handle(icon: Icons.close, color: Colors.redAccent),
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
              child: const _ResizeHandle(),
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
    final newX = (cfg.x + _dragAccum.dx / widget.cellWidth)
        .round()
        .clamp(0, model.cols - cfg.w);
    final newY = (cfg.y + _dragAccum.dy / widget.cellHeight)
        .round()
        .clamp(0, model.rows - cfg.h);
    widget.onDragUpdate?.call(newX, newY);
  }

  void _onDragEnd(DragEndDetails _) {
    final model = context.read<DashboardModel>();
    final cfg = widget.config;
    final newX = (cfg.x + _dragAccum.dx / widget.cellWidth)
        .round()
        .clamp(0, model.cols - cfg.w);
    final newY = (cfg.y + _dragAccum.dy / widget.cellHeight)
        .round()
        .clamp(0, model.rows - cfg.h);
    model.moveWidget(cfg.id, newX, newY);
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
    final gw = (widget.config.w + (_resizeWAccum / widget.cellWidth).round()).clamp(1, 99);
    final gh = (widget.config.h + (_resizeHAccum / widget.cellHeight).round()).clamp(1, 99);
    widget.onResizeUpdate?.call(gw, gh);
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

  // ---------------------------------------------------------------------------
  // Stream selector
  // ---------------------------------------------------------------------------

  void _showStreamSelector(BuildContext context, WidgetConfig cfg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0c0e1d),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<DashboardModel>(),
        child: StreamSelectorSheet(config: cfg),
      ),
    );
  }
}

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
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFF45866));
  }

  @override
  bool shouldRepaint(_TrianglePainter _) => false;
}
