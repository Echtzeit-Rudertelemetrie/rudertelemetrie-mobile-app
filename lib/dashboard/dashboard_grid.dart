import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dashboard_model.dart';
import 'dashboard_widget_tile.dart';
import 'widget_config.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Full-screen dashboard grid.
///
/// Drop this into any screen and provide a [widgetBuilder] that returns the
/// content widget for each tile.  The framework handles drag, resize, collision,
/// and edit-mode handles — it never inspects what your builder returns.
///
/// ```dart
/// DashboardGrid(
///   widgetBuilder: (context, config) => MyTileWidget(config: config),
/// )
/// ```
///
/// To add/remove/move widgets, access [DashboardModel] from the Provider tree:
/// ```dart
/// context.read<DashboardModel>().addWidget(WidgetConfig(...));
/// ```
class DashboardGrid extends StatefulWidget {
  /// Called for each tile to build its content. May return any widget.
  final Widget Function(BuildContext context, WidgetConfig config)
  widgetBuilder;

  const DashboardGrid({super.key, required this.widgetBuilder});

  @override
  State<DashboardGrid> createState() => _DashboardGridState();
}

class _DashboardGridState extends State<DashboardGrid> {
  /// Below this a tile is unreadable — in landscape a divided viewport would
  /// otherwise squash every row flat.
  static const _minCellHeight = 64.0;

  WidgetConfig? _ghost;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DashboardModel>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / model.cols;
        final cellH = math.max(
          _minCellHeight,
          constraints.maxHeight / DashboardModel.viewportRows,
        );

        return SingleChildScrollView(
          child: SizedBox(
            width: constraints.maxWidth,
            // Grows with the layout instead of packing tiles into a fixed
            // viewport, where a full grid used to overlap them silently.
            height: cellH * model.rows,
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
                        child: widget.widgetBuilder(context, cfg),
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
                          color: AppPalette.accent.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppPalette.accent.withAlpha(150),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
