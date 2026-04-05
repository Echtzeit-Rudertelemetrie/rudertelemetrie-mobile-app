import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_config.dart';
import 'package:rudertelemetrie_mobile_app/models/dashboard_model.dart';
import 'dashboard_widget_tile.dart';

/// Renders the full-screen grid.
///
/// Uses [LayoutBuilder] to derive pixel cell sizes from the available space,
/// then positions each widget with [AnimatedPositioned] inside a [Stack].
class DashboardGrid extends StatefulWidget {
  const DashboardGrid({super.key});

  @override
  State<DashboardGrid> createState() => _DashboardGridState();
}

class _DashboardGridState extends State<DashboardGrid> {
  // Ghost config while a widget is being dragged.
  WidgetConfig? _ghost;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DashboardModel>();
    final cols = model.cols;
    final rows = model.rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / cols;
        final cellH = constraints.maxHeight / rows;

        return SizedBox.expand(
          child: Stack(
            children: [
              // Widget tiles
              for (final cfg in model.layout)
                AnimatedPositioned(
                  key: ValueKey(cfg.id),
                  duration: _ghost?.id == cfg.id
                      ? Duration.zero // no animation while actively dragging
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
                      onDragUpdate: (gx, gy) => setState(
                        () => _ghost = cfg.copyWith(x: gx, y: gy),
                      ),
                      onDragEnd: () => setState(() => _ghost = null),
                      onResizeUpdate: (gw, gh) => setState(
                        () => _ghost = cfg.copyWith(w: gw, h: gh),
                      ),
                      onResizeEnd: () => setState(() => _ghost = null),
                    ),
                  ),
                ),

              // Ghost placeholder — rendered on top so it's visible when shrinking too
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
