# Architecture notes: building blocks the feature specs share

Status: **spec only.** This document names the handful of new abstractions that most of
the feature backlog hangs off, and maps them onto the code that exists today so the
individual specs can stay short. Nothing here is implemented yet.

## 1. What exists today (grounding)

Data flows: **`DataSource`** (a named `Stream<Measurement{value,timestamp}>` with a
`Unit` and optional `group`) → **`Combinator1/2`** (→ `Stream<XYPoint>`) →
**`PointFilter`** (optional) → **`PointCollector`** (→ `List<XYPoint>`) →
**`BoundVisualizer`** → tiles (`ValueTile`, `ChartTile`).

- Sources are produced live in `bluetooth_stream_handler.dart`: per oarlock
  `Force N`/`Angle N`, and boat `Speed`, `Acceleration X/Y/Z`. GPS lat/lon/course are
  **decoded but never registered** as sources.
- Visualizers are registered in `visualizer_provider.dart` (`Time Window`,
  `Since Threshold`, `X vs Y (Window)`, `X vs Y (Stroke)`).
- Dashboard: 4×8 grid, `WidgetConfig` with an opaque `data` map
  (`type` = `chart`|`value`, `visualizerKey`, `sourceKeys`, `params`). Add-widget UI in
  `add_widget_sheet.dart` groups sources by `DataSource.group`.

**Key consequence:** anything that can be expressed as *a new named stream* needs **no**
new widget code — it appears automatically in the source picker and works with every
existing visualizer and tile. That is the cheapest extension point and most computed
values should use it.

## 2. New building blocks

### 2.1 `DerivedDataSource` — a computed source (the workhorse)

A `DataSource` whose `data` stream is a function of one or more existing sources plus
config, emitting `Measurement`s like any sensor source. Registered into the same
`DataSourceRegistry`, so it shows up in the picker and flows into charts/value tiles for
free.

Covers: handle force, blade force, effective/lateral force, instantaneous power, blade
drift/efficiency, speed-km/h, pace, running averages (a wrapper), tilt.

Design points:
- Needs an N-source combine (current combinators cap at 2). Add a small
  `CombineLatestSource(sources, unit, group, compute)` that emits on each input using the
  latest of the others (align on nearest timestamp within a tolerance).
- Rig/session constants are captured at build time or read live from the config model.
- Should re-register when its inputs (dis)appear (oarlock connect/disconnect) — mirror
  the `DataSourceRegistry.notifyListeners` pattern.

### 2.2 `StrokeEngine` — cross-cutting stroke segmentation

A service consuming per-oarlock `Force`/`Angle` (+ boat `Accel`/`Speed`) that implements
the state machine in [`math/stroke-detection.md`](math/stroke-detection.md) and emits:

- a **stroke-event stream** (catch/finish/reversal/anrollen with crew aggregation), and
- **per-stroke `DerivedDataSource`s**: `Stroke Rate` (SPM), `Stroke Count`,
  `Drive:Recovery Ratio`, `Reversal→Catch Time`, `Distance per Stroke`, plus the
  per-stroke power/force aggregates from the force-power model. These emit **one
  `Measurement` per stroke**, timestamped at the finish.

The stroke-event stream is also the trigger for the per-stroke bar chart and the refined
per-stroke force/angle diagram.

### 2.3 `RecordingSession` — start/stop, clock, averages, peaks

Owns the single recording origin and lifecycle (idle → recording → stopped). Provides:

- `elapsed`, session distance (integrator + haversine), and
- **generic reducers** applied to any source: `RunningAverageSource(src)` and
  `SessionPeakSource(src)` (running max). "Averages of all sensible values" and "every
  per-stroke value also as a session peak" are these two wrappers, not N bespoke metrics.

Without an explicit session, "average since start" and "distance" have no well-defined
origin, so this is a prerequisite for that whole cluster of essential values.

### 2.4 `BoatConfig` / rig model

Holds boat class, seat→oarlock→(position, side) assignment, and per-oar `l_in`, `L`, and
`force_sensor_axis` (the angle arrives self-calibrated from firmware — no app-side angle
config). Feeds the force/power derived
sources, the boat schematic, and stroke crew-aggregation. A `ChangeNotifier` provider
persisted with the existing storage the dashboard layout uses. See
[`specs/boat-rig-config.md`](specs/boat-rig-config.md).

### 2.5 New collectors & tiles (only where a new *shape* is needed)

- `PerStrokeBarCollector` + `BarTile` — one bar per stroke for a per-stroke source.
- `CustomPaint` tiles that are **not** stream→XYPoint: `LevelTile`, `BoatSchematicTile`,
  `MapTile`. These bypass the visualizer pipeline and subscribe to sources directly (like
  `ValueTile` does), because their output isn't a list of XY points.

## 3. Dependency graph (build order)

```
BoatConfig ─┬─────────────► Force/Power derived sources ──► charts, value tiles, per-stroke bar
            │                        ▲
            └─► Boat schematic       │ (rig constants)
RecordingSession ─► elapsed, distance, averages, peaks
StrokeEngine ─► SPM, count, ratio, reversal→catch, distance/stroke, per-stroke power/force
      │
      └─► per-stroke bar chart, refined per-stroke force/angle diagram
GPS lat/lon sources ─► Map view
Accel sources ─► Level/acceleration widget
```

Foundational (unlock the most): **RecordingSession**, **StrokeEngine**, **BoatConfig**.
Leaf widgets depend on them but are individually small.

## 4. Conventions for the specs

Each spec states: importance & complexity (from the README matrix), dependencies, data
model / pipeline changes (reusing §2 blocks), UI surface, config/params, edge cases,
test notes, open questions. Specs must not restate math — they link to `math/`.
