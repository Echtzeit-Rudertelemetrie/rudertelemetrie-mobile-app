# 19 — Fixed 4×8 grid silently overlaps tiles once full

**Priority:** P2 · **Effort:** M · **Area:** dashboard

## Problem

The dashboard is a fixed 4-column × 8-row grid with no scrolling. When there is
no free slot for a new widget, `_findFreeSlot` falls back to `(0, 0)` and the
collision resolver gives up when there is no room below — so tiles are placed
**on top of each other with no warning**. The user sees a tile vanish under
another one and has no idea why.

Now that layouts are saved as presets and swapped, users will build denser
dashboards, so this will be hit more often.

## Evidence

- `lib/dashboard/dashboard_model.dart` — `_cols = 4`, `_rows = 8`, no scrolling.
- `lib/dashboard/dashboard_layout_engine.dart:179-190` — `_findFreeSlot`
  fallback: `// Fallback: place at (0, 0) — will be resolved by collision logic.`
- `lib/dashboard/dashboard_layout_engine.dart:165-171` — `_resolveCollisions`
  `continue`s when `newY + collider.h > rows`, with the comment
  `// If still no room, items will just overlap`.
- `lib/dashboard/dashboard_grid.dart:41-46` — `LayoutBuilder` divides the fixed
  viewport by `cols`/`rows`; nothing scrolls.

## Fix

Pick one of two directions:

**A — bounded grid, honest about it (smaller change).** Keep 4×8; make
`addWidget` return whether placement succeeded, and refuse with a clear message
("Dashboard full — remove a widget or create a new preset") instead of
overlapping. Disable the add buttons when nothing fits.

**B — growing grid (better UX).** Let rows grow beyond the viewport and make the
grid vertically scrollable, with a fixed row height instead of a divided one.
This also fixes tiles becoming unreadably short in landscape.

B is recommended; the preset feature makes long dashboards more likely, and a
scrollable grid removes the capacity question entirely. Note it changes the
meaning of `rows` in `DashboardLayoutEngine`, so the engine tests need revisiting.

## Acceptance criteria

- [ ] Tiles never silently overlap.
- [ ] (A) The user is told when the dashboard cannot fit another widget, or
      (B) the grid scrolls and tiles keep a legible minimum height.
- [ ] Existing saved presets still load and render correctly.
- [ ] `test/dashboard_layout_engine_test.dart` covers the full-grid case
      explicitly.
