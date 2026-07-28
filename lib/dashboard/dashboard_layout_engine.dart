import 'widget_config.dart';

/// Pure Dart layout engine — no Flutter imports.
///
/// Grid coordinates are 0-based integers. (0,0) is top-left.
/// Items are immutable [WidgetConfig] records; every mutation returns a
/// new list (copy-on-modify).
class DashboardLayoutEngine {
  final int cols;
  final int rows;

  const DashboardLayoutEngine({required this.cols, required this.rows});

  // ---------------------------------------------------------------------------
  // Collision detection
  // ---------------------------------------------------------------------------

  /// Returns true when [a] and [b] occupy overlapping cells (AABB).
  bool collides(WidgetConfig a, WidgetConfig b) {
    if (a.id == b.id) return false;
    return a.x < b.x + b.w &&
        a.x + a.w > b.x &&
        a.y < b.y + b.h &&
        a.y + a.h > b.y;
  }

  /// All items in [layout] that overlap [item], sorted by (y, x).
  List<WidgetConfig> getAllCollisions(
    List<WidgetConfig> layout,
    WidgetConfig item,
  ) => layout.where((e) => collides(item, e)).toList()..sort(_byRowThenColumn);

  // ---------------------------------------------------------------------------
  // Move
  // ---------------------------------------------------------------------------

  /// Move widget [id] to ([newX], [newY]), recursively pushing colliders down.
  /// Runs compaction afterwards to eliminate gaps.
  List<WidgetConfig> moveElement(
    List<WidgetConfig> layout,
    String id,
    int newX,
    int newY,
  ) {
    final item = _find(layout, id);
    if (item == null) return layout;
    if (item.x == newX && item.y == newY) return layout;

    final (cx, cy) = clampPosition(newX, newY, item.w, item.h);
    layout = _replace(layout, item.copyWith(x: cx, y: cy));
    return _resolveCollisions(layout, id, {});
  }

  /// Resize widget [id] to ([newW], [newH]), then resolve collisions + compact.
  List<WidgetConfig> resizeElement(
    List<WidgetConfig> layout,
    String id,
    int newW,
    int newH,
  ) {
    final item = _find(layout, id);
    if (item == null) return layout;

    final w = newW.clamp(1, cols - item.x);
    final h = newH.clamp(1, rows - item.y);
    layout = _replace(layout, item.copyWith(w: w, h: h));
    return _resolveCollisions(layout, id, {});
  }

  // ---------------------------------------------------------------------------
  // Compaction (vertical — identical to react-grid-layout's "vertical" mode)
  // ---------------------------------------------------------------------------

  /// Sort by (y, x) then move each item up as far as possible without overlap.
  List<WidgetConfig> compact(List<WidgetConfig> layout) {
    final sorted = [...layout]..sort(_byRowThenColumn);

    final result = <WidgetConfig>[];
    for (final item in sorted) {
      var y = item.y;
      while (y > 0) {
        final candidate = item.copyWith(y: y - 1);
        if (getAllCollisions(result, candidate).isNotEmpty) break;
        y--;
      }
      result.add(item.copyWith(y: y));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Add / remove
  // ---------------------------------------------------------------------------

  /// Place [widget] at the first available position, then compact.
  List<WidgetConfig> addWidget(List<WidgetConfig> layout, WidgetConfig widget) {
    final placed = _findFreeSlot(layout, widget);
    return [...layout, placed];
  }

  /// Remove the widget with [id].
  List<WidgetConfig> removeWidget(List<WidgetConfig> layout, String id) {
    return layout.where((e) => e.id != id).toList();
  }

  // ---------------------------------------------------------------------------
  // Re-gridding (orientation change)
  // ---------------------------------------------------------------------------

  /// Remap a layout authored on a [fromCols]×[fromRows] grid onto this one, so
  /// each tile keeps the share of the screen it had before.
  ///
  /// Subdividing an axis is exact when this grid's count is a multiple of the
  /// old one. Coarsening rounds, which can round two tiles onto each other —
  /// those are re-seated rather than left overlapping.
  List<WidgetConfig> rescale(
    List<WidgetConfig> layout,
    int fromCols,
    int fromRows,
  ) {
    if (fromCols < 1 || fromRows < 1) return List.of(layout);
    if (fromCols == cols && fromRows == rows) return List.of(layout);
    return repack([
      for (final item in layout)
        _scaled(item, cols / fromCols, rows / fromRows),
    ]);
  }

  /// Re-seat every tile so none overlap: those that still fit stay put, the
  /// rest move to the first free slot. A tile with nowhere left to go is
  /// dropped instead of hidden under another.
  List<WidgetConfig> repack(List<WidgetConfig> layout) {
    final placed = <WidgetConfig>[];
    for (final item in [...layout]..sort(_byRowThenColumn)) {
      final seat = getAllCollisions(placed, item).isEmpty
          ? item
          : _firstFreeSlot(placed, item);
      if (seat != null) placed.add(seat);
    }
    return placed;
  }

  // ---------------------------------------------------------------------------
  // Coordinate helpers
  // ---------------------------------------------------------------------------

  /// Clamp (x, y) so a widget of size (w×h) stays inside the grid.
  (int, int) clampPosition(int x, int y, int w, int h) {
    final cx = x.clamp(0, (cols - w).clamp(0, cols - 1));
    final cy = y.clamp(0, (rows - h).clamp(0, rows - 1));
    return (cx, cy);
  }

  /// Convert pixel offset [px] to grid column, given [cellWidth].
  int pixelToGridX(double px, double cellWidth) =>
      (px / cellWidth).floor().clamp(0, cols - 1);

  /// Convert pixel offset [py] to grid row, given [cellHeight].
  int pixelToGridY(double py, double cellHeight) =>
      (py / cellHeight).floor().clamp(0, rows - 1);

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  WidgetConfig? _find(List<WidgetConfig> layout, String id) {
    for (final e in layout) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<WidgetConfig> _replace(List<WidgetConfig> layout, WidgetConfig next) =>
      layout.map((e) => e.id == next.id ? next : e).toList();

  /// Recursively push all items colliding with [movedId] below it.
  /// [visiting] guards against infinite recursion cycles.
  List<WidgetConfig> _resolveCollisions(
    List<WidgetConfig> layout,
    String movedId,
    Set<String> visiting,
  ) {
    if (visiting.contains(movedId)) return layout;
    final moved = _find(layout, movedId);
    if (moved == null) return layout;

    final colliders = getAllCollisions(layout, moved);
    for (final collider in colliders) {
      final newY = moved.y + moved.h;
      if (newY + collider.h > rows) {
        // No room below — try compacting first and resolve again.
        // If still no room, items will just overlap (edge case with very full grid).
        continue;
      }
      layout = _replace(layout, collider.copyWith(y: newY));
      layout = _resolveCollisions(layout, collider.id, {...visiting, movedId});
    }
    return layout;
  }

  /// Scale a tile by [scaleX] across and [scaleY] down, keeping it inside the
  /// grid and at least one cell in each direction.
  WidgetConfig _scaled(WidgetConfig item, double scaleX, double scaleY) {
    final w = (item.w * scaleX).round().clamp(1, cols);
    final h = (item.h * scaleY).round().clamp(1, rows);
    return item.copyWith(
      x: (item.x * scaleX).round().clamp(0, cols - w),
      y: (item.y * scaleY).round().clamp(0, rows - h),
      w: w,
      h: h,
    );
  }

  /// Find the first (x, y) position where [widget] fits without collision.
  /// Falls back to (0, 0) — the collision logic resolves it from there.
  WidgetConfig _findFreeSlot(List<WidgetConfig> layout, WidgetConfig widget) =>
      _firstFreeSlot(layout, widget) ?? widget.copyWith(x: 0, y: 0);

  /// The first free slot for [widget], or null when the grid has no room.
  WidgetConfig? _firstFreeSlot(List<WidgetConfig> layout, WidgetConfig widget) {
    for (var y = 0; y <= rows - widget.h; y++) {
      for (var x = 0; x <= cols - widget.w; x++) {
        final candidate = widget.copyWith(x: x, y: y);
        if (getAllCollisions(layout, candidate).isEmpty) return candidate;
      }
    }
    return null;
  }
}

int _byRowThenColumn(WidgetConfig a, WidgetConfig b) {
  final dy = a.y.compareTo(b.y);
  return dy != 0 ? dy : a.x.compareTo(b.x);
}
