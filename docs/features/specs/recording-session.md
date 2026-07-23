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
- `distanceMeters` — dual estimator (integrate `Speed`; haversine over GPS fixes), see
  math §2. Prefer haversine when GPS valid, else the integrator.
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

Sessions are **persisted** (the PO wants history + export). On stop, write a session
record — metadata (`startedAt`, `stoppedAt`, `startMode`, boat/rig config snapshot,
distance, and per-metric summaries: averages + session peaks) plus the raw/derived sample
series needed to reconstruct charts. Reuse the storage the dashboard layout already uses;
for the sample series consider a compact append-only log per session.

- **Export** each session as CSV and/or JSON (per-stream columns + a summary header).
  Treat export as a file the user shares — surface a share/save action; don't auto-upload.
- A **session history** list lets the user open a past session read-only (replay charts,
  view summaries) and export it.
- Storage growth: 100 Hz × several streams adds up — offer a retention limit / delete, and
  consider downsampling the stored series for long sessions.

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

## Open questions

1. ~~Persist vs. live-only?~~ **Decided: persist + export** (CSV/JSON, history screen).
2. ~~Auto-start vs. manual?~~ **Decided: both** — auto-start on detected rowing with a
   manual override/reset.
3. Export format details (CSV column set, JSON schema) and retention/downsampling policy —
   settle when building the export.
