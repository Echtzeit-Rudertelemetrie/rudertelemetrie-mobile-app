# Spec: Per-stroke bar chart

**Importance:** Nice-to-have · **Complexity:** Medium
**Depends on:** `StrokeEngine` (per-stroke sources) · **Unlocks:** at-a-glance
stroke-to-stroke consistency for any selectable per-stroke value.

## What

"Balkendiagramm mit 1 Balken pro Schlag für auswählbare Werte" — a bar chart where each
bar is one stroke and the height is a chosen per-stroke value (SPM, peak power, peak
force, distance/stroke, ratio, …). Shows a rolling window of the last K strokes.

## Pipeline

- New `PerStrokeBarCollector` (a `PointCollector`): accumulates one `XYPoint` per stroke
  (x = stroke index or finish time, y = the per-stroke value), keeping the last K.
- Source = any per-stroke `DerivedDataSource` from the stroke engine or force-power specs
  (they emit exactly one `Measurement` per stroke, so the collector is trivial — no
  segmentation logic in the widget).
- New `BarTile` renders the list as bars (reuse the charting lib already behind
  `ChartTile`; bar series instead of line).

## UI

- Add "Bar" as a third add-widget button next to Chart/Value in `add_widget_sheet.dart`.
- Param: `strokeWindow K` (default ~20). Optional: colour bar by deviation from the
  session average / a target band.
- X labels: stroke number; optionally the newest bar highlighted.

## Edge cases

- Before any stroke completes → empty chart with "waiting for strokes".
- Non-per-stroke source selected → disallow (only per-stroke sources valid for this tile),
  or fall back to sampling at each stroke boundary.

## Open questions
1. Fixed window K vs. whole-session with horizontal scroll? Assume rolling K for v1.
