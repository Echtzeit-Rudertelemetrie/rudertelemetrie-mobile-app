import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dashboard_model.dart';
import 'dashboard_widget_tile.dart';
import 'widget_config.dart';

/// Fills the available space with the dashboard grid.
///
/// Uses [LayoutBuilder] to derive cell dimensions, then positions each
/// widget with [AnimatedPositioned] inside a [Stack]. A ghost overlay
/// tracks drag/resize previews.
class DashboardGrid extends StatefulWidget {
  const DashboardGrid({super.key});

  @override
  State<DashboardGrid> createState() => _DashboardGridState();
}

class _DashboardGridState extends State<DashboardGrid> {
  WidgetConfig? _ghost;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DashboardModel>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / model.cols;
        final cellH = constraints.maxHeight / model.rows;

        return SizedBox.expand(
          child: Stack(
            children: [
              for (final cfg in model.layout)
                AnimatedPositioned(
                  key: ValueKey(cfg.id),
                  duration: _ghost?.id == cfg.id
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  left: cfg.x * cellW,
                  top: cfg.y * cellH,
                  width: cfg.w * cellW,
                  height: cfg.h * cellH,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: DashboardWidgetTile(
                      config: cfg,
                      cellWidth: cellW,
                      cellHeight: cellH,
                      onDragUpdate: (gx, gy) =>
                          setState(() => _ghost = cfg.copyWith(x: gx, y: gy)),
                      onDragEnd: () => setState(() => _ghost = null),
                      onResizeUpdate: (gw, gh) =>
                          setState(() => _ghost = cfg.copyWith(w: gw, h: gh)),
                      onResizeEnd: () => setState(() => _ghost = null),
                    ),
                  ),
                ),

              if (_ghost != null)
                Positioned(
                  left: _ghost!.x * cellW,
                  top: _ghost!.y * cellH,
                  width: _ghost!.w * cellW,
                  height: _ghost!.h * cellH,
                  child: IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF45866).withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFF45866).withAlpha(150),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
