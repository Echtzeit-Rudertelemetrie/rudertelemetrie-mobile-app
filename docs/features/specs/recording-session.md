# Spec: Recording session, elapsed, distance, averages & peaks

**Importance:** Essential · **Complexity:** Low–Medium (foundational)
**Depends on:** existing `Speed`/GPS sources · **Unlocks:** every "since start" and
"session peak" value, distance/km, pace context.
**Math:** [`../math/kinematics-and-derived-metrics.md`](../math/kinematics-and-derived-metrics.md).

## Problem

Today sources carry a per-stream `startTime`, but there is no single recording origin, so
"average since start", "distance", "elapsed", and "session peak" are undefined. This spec
introduces one lifecycle object that everything time-relative hangs off.

## `RecordingSession` (ChangeNotifier)

State: `idle → recording → stopped`, with `start()`, `stop()`, `reset()`.

**Start/stop policy — auto + manual (both).** By default the session **auto-starts** when
the stroke engine first detects rowing and **auto-stops** after an idle timeout
(`T_idle_session`, e.g. 20 s of no strokes), so a crew never forgets to hit record. A
**manual override** always wins: an explicit start/stop/reset button can begin/end a
session regardless of detection, and manual stop disables auto-restart until the user
re-arms it. This makes auto-start depend on the `StrokeEngine` being live; before the
engine exists, fall back to manual-only.

Holds `startedAt`, `stoppedAt`, and a `startMode ∈ {auto, manual}` flag for the UI.
Exposes:

- `elapsed` — ticking `Duration` (`now − startedAt`), formatted `h:mm:ss`.
- `speedMps` — **position-derived** speed (`Δs/Δt` over GPS fixes, math §1/§2.2), the basis
  for `Speed (km/h)`, `Pace`, and `Distance`. The raw firmware `Speed` source is only a
  coarse fallback when GPS position is stale. Computed by a small `GpsKinematics` helper
  that consumes the `Latitude`/`Longitude` sources (exposed per
  [`widget-map.md`](widget-map.md) — this is a shared prerequisite, not map-only).
- `distanceMeters` — dual estimator (haversine over GPS fixes; integrate `speedMps` as
  fallback), math §2. Prefer haversine when GPS valid, else the integrator.
- reducer factories usable on any `DataSource`:
  - `RunningAverageSource(src)` → time-weighted mean since `startedAt` (math §5).
  - `SessionPeakSource(src)` → running max since `startedAt`.

These reducers are the mechanism for **"Durchschnittswerte von allen Werten"** and
**"jeder Pro-Schlag-Wert auch als Peak seit Session-Start"** — one implementation, wrapped
around whichever source the user picks, rather than dozens of bespoke metrics.

## Derived sources registered

| Source name | Unit | Definition |
|-------------|------|------------|
| `Speed (km/h)` | km/h | `v · 3.6`, with `v` **position-derived** (firmware speed is integer m/s — kinematics §1) |
| `Pace (/500m)` | s (fmt m:ss) | `500 / v`, blanked for `v < 0.3` |
| `Distance` | m/km | session integrator/haversine over ×1e6 lat/lon fixes |
| `Elapsed` | s (fmt h:mm:ss) | `now − startedAt` |
| `Avg <X>` | X's unit | `RunningAverageSource` over chosen source |
| `Peak <X>` | X's unit | `SessionPeakSource` over chosen source |

`Speed (km/h)`, `Pace`, `Distance`, `Elapsed` appear in the normal source picker and work
with the existing `ValueTile`. `Avg`/`Peak` need a small UI affordance to pick the base
source (see UI).

## Persistence & export

Every session is persisted. On `stop()`, write a session record:

- **`session.json`** — metadata + summary: `id`, `startedAt`, `stoppedAt`, `startMode`,
  a `BoatConfig` snapshot (boat class, per-oarlock `l_in`/`L`, seat/side assignment),
  `distanceMeters`, `strokeCount`, and per-metric `avg`/`peak` for speed, SPM, ratio,
  power, force, and distance-per-stroke.
- **`session.csv`** — the time series in **long format**: `elapsed_ms,source,value` (one
  row per sample per source). Long format sidesteps aligning streams of differing rates
  into one wide table and round-trips every registered source.

Storage:
- Reuse the local store the dashboard layout uses (documents-dir file per session + an
  index). Write `session.csv` as an **append-only log during recording**, so the full
  series is never held in memory.
- **Retention**: keep series at full 100 Hz; cap stored sessions (default: last 50 **or** a
  size budget, whichever hits first) and expose delete. Series older than the cap may be
  downsampled to 10 Hz for chart replay while `session.json` summaries stay full-fidelity.
- **Export/share**: a share/save action emits `session.csv` (+ `session.json`) via the
  platform share sheet — never auto-upload.
- A **session history** screen lists saved sessions; opening one replays its charts
  read-only and offers export.

## UI

- **Session control**: start/stop/reset control on the dashboard (record button in the
  header) showing whether the current session started `auto` or `manual`. Elapsed +
  distance shown near it. Stopping freezes derived values and writes the session record.
- **History**: a screen listing saved sessions with open + export actions.
- **Avg/Peak wrapping**: in `add_widget_sheet`, add a "reduction" dropdown
  (`raw` | `average` | `peak since start`) on any single-source value tile, so the user
  turns "Speed" into "Avg Speed" / "Peak Speed" without new visualizer entries.

## Edge cases

- No GPS fix yet → distance uses integrator; if `Speed` is also stale, hold last value,
  don't accumulate drift.
- `reset()` clears integrators, averages, peaks, and re-bases `elapsed`.
- Averages must be time-weighted (irregular sample rate) — do **not** use a naive running
  count mean.
- Pace/speed use the **position-derived** speed (firmware speed is integer-truncated m/s,
  kinematics §1); the raw `Speed` stream is only a coarse fallback when GPS position is
  stale.

## Test notes

- Feed a constant `Speed = 5 m/s` for 60 s → `Distance = 300 m`, `Speed(km/h)=18`,
  `Pace = 100 s = 1:40/500m`, `Avg Speed = 5`.
- Step signal → `SessionPeakSource` holds the max; `RunningAverageSource` converges.
- Note the constant-speed vector needs the position-derived `v`; a firmware `Speed` of a
  flat `5 m/s` would already be quantised, so drive the test from synthetic GPS fixes.
- Round-trip a recorded session through `session.csv` → reopen from history → chart matches.
