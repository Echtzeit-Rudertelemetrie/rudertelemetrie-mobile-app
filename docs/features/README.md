# Feature backlog & specs — rudertelemetrie_mobile_app

Scope: the **app** (`rudertelemetrie_mobile_app`). The `rowing_boat` firmware is
referenced only where the wire format or a firmware constant matters.

## How to read this

- [`architecture.md`](architecture.md) — the shared building blocks (`DerivedDataSource`,
  `StrokeEngine`, `RecordingSession`, `BoatConfig`) that most features hang off, mapped
  onto the code that exists today. **Read this first.**
- [`math/`](math/) — full mathematics, standalone: stroke detection, force/power,
  kinematics.
- [`specs/`](specs/) — per-feature implementation specs. Each links to its math and states
  importance, complexity, dependencies, pipeline changes, UI, edge cases, tests.

## Aggregated backlog

Importance uses the PO's own weighting (Essential / Nice-to-have / Very-nice-to-have /
deprioritised). Complexity is engineering effort against the current architecture.

### By importance

**Essential**
- The computed **values** — the PO stressed these above all:
  - Stroke detection & phases (Anrollen, Umkehr, Setzen, Setzen→Ende) → SPM (per-stroke,
    extrapolated), stroke count, Freilauf:Durchzug ratio, Umkehr→Setzen time,
    distance-per-stroke. → [`specs/stroke-engine.md`](specs/stroke-engine.md)
  - Speed km/h & pace /500m, distance/km, elapsed time, running averages, session peaks.
    → [`specs/recording-session.md`](specs/recording-session.md)
  - Force (grip/blade/oarlock), power (instantaneous / avg / peak per stroke), effective
    vs. lost force & power, blade drift & efficiency. →
    [`specs/force-power-derived.md`](specs/force-power-derived.md)
  - **Rig inputs** (`l_in`, `L`) — hard prerequisite for all force/power (the angle needs
    no app config; it self-calibrates in firmware).
    → [`specs/boat-rig-config.md`](specs/boat-rig-config.md) Part A
- Live **scull/boat angle** visualisation (at minimum per-scull gauges). →
  [`specs/widget-boat-schematic.md`](specs/widget-boat-schematic.md) Tier 1
- Per-stroke force/angle curve (upgrade of an existing feature). →
  [`specs/widget-per-stroke-force-angle.md`](specs/widget-per-stroke-force-angle.md)
- *Already implemented:* continuous chart for arbitrary values (`Time Window` +
  `ChartTile`), individual current values (`ValueTile`). Kept as-is; minor enhancements
  only.

**Nice-to-have**
- Spirit-level & acceleration widget → [`specs/widget-level-acceleration.md`](specs/widget-level-acceleration.md)
- Per-stroke bar chart (1 bar/stroke, selectable value) →
  [`specs/widget-per-stroke-bar-chart.md`](specs/widget-per-stroke-bar-chart.md)

**Very nice-to-have**
- Boat schematic from above with live oar angles →
  [`specs/widget-boat-schematic.md`](specs/widget-boat-schematic.md) Tier 2
- Map with GPS position (OSM) → [`specs/widget-map.md`](specs/widget-map.md)
- Boat/crew setup with graphics & rigging (PO explicitly said to deprioritise) →
  [`specs/boat-rig-config.md`](specs/boat-rig-config.md) Part B

### By complexity

| Complexity | Items |
|-----------|-------|
| **Trivial / Low** | speed km/h, pace/500m, elapsed time, distance/km, generic running averages & session peaks; handle/blade/effective/lateral force (algebra); rig number inputs; per-stroke force/angle curve upgrade |
| **Medium** | instantaneous power, blade drift & efficiency (need `ω`); per-stroke aggregates; per-stroke bar chart; spirit-level widget; expose GPS lat/lon; per-scull angle gauges (Tier 1) |
| **High** | stroke phase detection engine (Anrollen/Umkehr/Setzen + crew sync); boat schematic top-view; map view (tiles/offline/dependency); full boat+crew setup with graphics |

### Foundations that unlock the most (build first)

`RecordingSession`, `StrokeEngine`, and `BoatConfig` (rig part) are each depended on by a
whole cluster of essential values. See the dependency graph in
[`architecture.md`](architecture.md) §3.

## Suggested roadmap (phased)

1. **Phase 0 — plumbing:** `RecordingSession` with **manual** start/stop + persistence &
   CSV/JSON export groundwork; **expose GPS lat/lon** → position-derived speed, distance,
   elapsed, generic avg/peak. Cheap, unlocks many essential numbers immediately.
2. **Phase 1 — rig & simple force:** `BoatConfig` Part A (lever inputs only — the angle
   self-calibrates in firmware) → handle/blade/effective/lateral force sources (pure algebra).
3. **Phase 2 — strokes:** `StrokeEngine` → SPM, count, ratio, Umkehr→Setzen,
   distance/stroke; then per-stroke bar chart and the refined force/angle curve. Wire the
   "rowing/not-rowing" signal into the session's **auto-start/stop** (manual override
   stays).
4. **Phase 3 — power:** instantaneous power, blade drift/efficiency, per-stroke power/force
   aggregates (build on Phases 1–2).
5. **Phase 4 — essential visuals + history:** per-scull angle gauges (schematic Tier 1),
   spirit-level widget, session **history screen**.
6. **Phase 5 — nice-to-have visuals:** boat schematic Tier 2, **map view (cached offline
   region)**, boat/crew setup with graphics.

### Product decisions (from the PO)

- **Recording:** auto-start on detected rowing **and** manual start/stop/reset override.
- **Sessions:** persisted with CSV/JSON **export** and a history screen (not live-only).
- **Stroke thresholds:** **both** absolute and auto-scaled (`k·F_peak`), user-selectable.
- **Map:** **cached offline region** (pre-download tiles), with track-only as the fallback.

## Cross-cutting facts (resolved against the `rowing_boat` firmware)

The questions that biased multiple features have been answered from the firmware and the
PO. Details in the linked docs:

1. **Angle convention — ✅ ±180° full range, self-calibrated in firmware.** `DataSender.h`
   encodes `angle_deg = code/65535·360 − 180`; the app decoder already matches (its `−90…90°`
   *comment* is stale — copied from the out-of-date `SimData`). The angle is an ICM-20948
   orientation-EKF estimate that **zeroes and calibrates itself in firmware** — the app
   consumes the signed angle directly and performs **no angle calibration**.
   (stroke-detection §1.1)
2. **GPS speed — ✅ integer-truncated m/s → derive from position.** `Gps.cpp` casts
   `speed.mps()` into `int16`, so speed arrives in whole-m/s (3.6 km/h) steps. The app uses
   **position-derived speed** (`Δs/Δt` over ×1e6 lat/lon fixes) as primary; the firmware
   `Speed` stream is a coarse fallback. A firmware `speed·100` fix is noted but not required.
   (kinematics §1)
3. **Force sensor axis — ✅ perpendicular.** Load cell reads the scull pressing on the pin;
   0–1000 N full scale. Standard `F·cos θ` projection applies. (force-power §1)
4. **Per-oarlock sample rate — ✅ 100 Hz.** ForceReader/AngleReader at 10 ms; sets the
   angle LPF/`ω` step. (stroke-detection §1.2)
5. **IMU — ⚠️ units m/s² confirmed, orientation still open.** `ImuData` is m/s², but the
   **boat IMU is currently simulated** (`SimData::imu`); the real axis mapping/signs are a
   fixed property of the mounting, read off firmware when a physical hub IMU (LSM6DS/MPU) is
   added — not an app-side calibration. Sim convention meanwhile: `acc_z` up, `acc_x`
   longitudinal, `acc_y` lateral. (kinematics §6, level widget)

Firmware cleanup items spotted in passing (not app work): the stale ±90° `SimData` angle
encoding vs. the real ±180° `DataSender` path, and the app's stale angle code comment.

## Notes on the existing pipeline (why most values need no new widgets)

The app already turns any registered `DataSource` into charts and value tiles via the
`DataSource → Combinator → Collector → Visualizer` pipeline. Most computed values are
therefore modelled as **new derived sources**, appearing automatically in the widget
picker — only genuinely new *shapes* (bars, level, boat schematic, map) need new tiles.
See [`architecture.md`](architecture.md).
