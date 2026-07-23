# Spec: Stroke engine & per-stroke metrics

**Importance:** Essential · **Complexity:** High (foundational)
**Depends on:** `Force`/`Angle` sources, `Accel`/`Speed`, `BoatConfig` (crew aggregation) ·
**Unlocks:** SPM, stroke count, drive/recovery ratio,
reversal→catch, distance-per-stroke, per-stroke bar chart, refined force/angle diagram.
**Math:** [`../math/stroke-detection.md`](../math/stroke-detection.md) (segmentation),
[`../math/kinematics-and-derived-metrics.md`](../math/kinematics-and-derived-metrics.md) §3.

## Problem

Almost every "essential value" in the PO's list is defined per stroke, which requires
detecting stroke boundaries and the intra-stroke events (Anrollen, Umkehr, Setzen). There
is no such detection today — the only stroke-ish primitive is `SinceThresholdCollector`
(a raw force threshold, no event semantics).

## `StrokeEngine` service

Consumes the fused per-oarlock `(θ, ω, F)` stream (+ boat `a_x`, `v`) and runs the
hysteresis state machine from stroke-detection §5, per oarlock, then aggregates to crew
level (§3) using `BoatConfig` (which oarlock is bow / which aggregation mode).

Fusion happens **inside the engine**: it owns a resampler that aligns all inputs onto one
100 Hz clock (all sensors sample at 100 Hz), computes `ω` from the smoothed angle
(stroke-detection §1.2), and feeds the state machine — callers never align streams.

Emits two things:

1. **`Stream<StrokeEvent>`** — `{type: catch|finish|reversal|anrollen, oarlock, tCrew, spread}`.
   Used as a trigger by the per-stroke bar chart and the force/angle diagram.
2. **Per-stroke `DerivedDataSource`s** (one `Measurement` per closed cycle, timestamped at
   the crew finish), listed below.

### Registered per-stroke sources

| Source name | Unit | Definition (math ref) |
|-------------|------|------------------------|
| `Stroke Rate` | 1/min | `SPM[n] = 60/T_stroke[n]` (detection §4) — per-stroke, not rolling |
| `Stroke Count` | count | increments at each crew finish since session start |
| `Drive:Recovery Ratio` | ratio | `T_recovery/T_drive` (detection §4) |
| `Reversal→Catch Time` | s | `t_catch − t_reversal` (detection §2.3) |
| `Distance per Stroke` | m | `s_stroke[n]` (kinematics §3) |
| `Catch Angle` / `Finish Angle` / `Sweep` | deg | per-cycle angle extremes (detection §4) |
| `Crew Sync (finish)` | s | `σ_finish` spread across oarlocks (detection §3) |

Power/force per-stroke aggregates (`Avg/Peak Power`, `Peak Force`, blade drift/stroke)
are defined in [`force-power-derived.md`](force-power-derived.md) but attach to the **same**
cycle boundary emitted here, so all per-stroke values share one timeline.

## Parameters

Exposed as engine settings (defaults in detection §6): **threshold mode**
(`absolute` | `auto-scaled`, user-selectable — detection §2.1), `F_on`/`F_off` (or
`k_on`/`k_off` in auto mode), `τ_min`, `τ_stroke_min`, `a_on`, `T_idle`, angle LPF cutoff
(fs = 100 Hz), crew aggregation mode. The stroke-detected "rowing / not rowing" signal also
drives the recording session's auto-start/stop.

## UI

- Per-stroke sources appear in the normal picker (group "Stroke") → usable in `ValueTile`
  and the new bar chart.
- A **"not rowing"** state (idle > `T_idle`) should blank `Stroke Rate` rather than show a
  stale huge period.
- Optional: a small "phase" indicator showing the current detected phase live.

## Edge cases

- `m = 1` oarlock: crew aggregation is identity; still works.
- Warm-up: first cycle only after one full catch→finish (detection §5 guards).
- Debounce spurious catches (`T_drive < τ_min`) and impossibly fast strokes
  (`T_stroke < τ_stroke_min`).
- Anrollen unavailable if IMU noisy → emit event as null, don't fail the cycle.
- The angle is self-calibrated in firmware, so angle-based events (Umkehr, catch/finish
  angles) need no app-side calibration gate.

## Field tuning (needs real water data)

The defaults in stroke-detection §6 are starting points; tune against recorded sessions:

- `k_on`/`k_off` (auto threshold mode) and the warm-up seeding.
- `a_on` (Anrollen surge threshold).
- Umkehr is defined as the per-oarlock angle turning point (primary); cross-check it
  against the boat-speed minimum on real data. Boat speed is coarse (kinematics §1), so the
  angle turning point remains primary regardless.

Ship the values as engine settings so they can be tuned without a rebuild.

## Test notes

- Synthetic `(θ, F)` generator producing N clean cycles at a set rate → assert
  `Stroke Count = N`, `SPM ≈ set rate`, `ratio ≈ set ratio`.
- Inject a sub-`τ_min` force blip mid-recovery → must **not** create a cycle.
- Two desynchronised oarlocks → `Crew Sync` equals the injected offset.
