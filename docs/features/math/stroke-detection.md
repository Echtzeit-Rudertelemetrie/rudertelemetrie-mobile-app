# Math: Stroke detection & phase segmentation

Status: **spec / math only** — no implementation yet.
Consumes: per-oarlock `Angle N` (deg) and `Force N` (N), boat `Speed` (m/s) and
`Acceleration X` (m/s², longitudinal). Produces: a stream of stroke events used by
[`../specs/stroke-engine.md`](../specs/stroke-engine.md).

This document defines, purely mathematically, how a rowing stroke is split into its
phases from the available signals. It deliberately does **not** describe Dart types —
see the stroke-engine spec for that.

---

## 1. Signal model and conventions

For one oarlock we have two synchronised sampled signals (same timestamps, from the
same `MeasurementPack`):

- oar angle `θ(t)` in degrees,
- oarlock force `F(t)` in newtons (the perpendicular-to-shaft component — see the
  [force/power model](force-power-model.md) for why this matters).

### 1.1 Angle sign convention

We require a **signed** angle with a fixed zero and orientation:

- `θ = 0` when the oar shaft is perpendicular to the boat's long axis (square/mid-drive).
- `θ > 0` toward the **bow** (catch side, arms extended, legs compressed).
- `θ < 0` toward the **stern** (finish side, hands at the body).

So over one cycle `θ` moves `θ_catch (max +) → θ_finish (max −) → θ_catch`.

**Angle encoding:** the app decodes the raw `uint16` to a signed **±180° full range**
(`angle_conversion_util.dart`, `−180 + raw·360/65535`, ≈0.0055°/LSB). Its `−90…+90°` code
comment is stale and should be corrected — the ±180° decode itself is right.

Each oarlock derives the angle from an ICM-20948 (accel + gyro + magnetometer) through an
orientation EKF (`AngleReader`). **The sensor zeroes and calibrates itself entirely in
firmware — the app performs no angle calibration.** The app consumes the delivered signed angle directly and assumes it already
follows the convention above (zero at the perpendicular, positive toward the bow); any zero
or drift correction is the firmware's responsibility.

All formulas below use the incoming `θ` as delivered.

### 1.2 Angular velocity

`ω(t) = dθ/dt` in **rad/s**:

```
ω(t) = (π/180) · dθ_deg/dt
```

The raw signal is noisy, so `ω` is computed on a smoothed angle. Recommended
discrete estimator (central difference on a low-pass-filtered angle):

```
θ̃[k] = LPF(θ[k])                      # 1st-order IIR, cutoff ≈ 3–5 Hz
ω[k]  = (π/180) · (θ̃[k+1] − θ̃[k−1]) / (t[k+1] − t[k−1])
```

**Sample rate — confirmed 100 Hz.** `ForceReader`/`AngleReader` sample at 10 ms
(`SAMPLE_INTERVAL_US = 10000`), and `AppTypes.h` documents "Sensor sampelt mit 100 Hz"
with `PACKET_VALUES = 10` ⇒ 10 packets/s per oarlock. So Nyquist is 50 Hz and the 3–5 Hz
LPF below sits comfortably under it. All thresholds are rate-independent (physical units);
only the LPF cutoff and the `ω` finite-difference step depend on the rate, and both are now
pinned to 100 Hz.

---

## 2. The stroke cycle and its events

One **stroke cycle** contains a **drive** (Durchzug, blade in the water, force high)
and a **recovery** (Freilauf, blade out, force ≈ 0). The PO's five events, ordered
within one cycle starting at the finish:

| # | Event (DE)            | Meaning                                              | Primary signal |
|---|-----------------------|------------------------------------------------------|----------------|
| 1 | **Ende / Finish**     | hands at the body; blade released; cycle boundary     | `F` falls below `F_off` |
| 2 | **Beginn** (arms extend) | recovery starts, hands/body move away                | first sustained `ω < 0` after finish |
| 3 | **Anrollen**          | legs start pulling the boat forward under the rower   | boat-surge accel peak during recovery |
| 4 | **Umkehr** (reversal) | oar reaches the catch extreme; forward motion reverses | `θ` turning point (`ω` sign flip + → −) |
| 5 | **Setzen / Catch**    | blade enters water, load begins, drive starts         | `F` rises above `F_on` |

The PO's cycle boundary is the **finish** ("Ein Schlag beginnt … wenn alle Ruderer
ihre Hände am Körper haben"). We therefore count strokes at the finish.

### 2.1 Catch and finish — force threshold with hysteresis

Let `F_on > F_off > 0` be two thresholds (hysteresis prevents chatter around the
release). Define crossing times per cycle `n`:

```
t_catch[n]  = first t where F(t) crosses upward through F_on   (drive begins)
t_finish[n] = first t after t_catch[n] where F(t) crosses downward through F_off
```

- **Drive interval** `D[n] = [t_catch[n], t_finish[n]]`.
- **Recovery interval** `R[n] = [t_finish[n], t_catch[n+1]]`.

**Threshold mode — both, user-selectable** (product decision):

- **Absolute** (default): fixed `F_on ≈ 40 N`, `F_off ≈ 20 N`. Simple and predictable;
  may need re-tuning per athlete/boat.
- **Auto-scaled**: `F_on = k_on · F_peak_recent`, `F_off = k_off · F_peak_recent` with
  `F_peak_recent` a slow rolling max of drive peak force (e.g. EMA over the last few
  strokes) and `k_on > k_off` (e.g. 0.15 / 0.08). Adapts across athletes/rigs
  automatically. Needs a warm-up seed (use the absolute defaults until `F_peak_recent`
  stabilises).

A UI toggle picks the mode; both share the hysteresis (`F_on > F_off`) and the
**minimum drive duration** `τ_min ≈ 0.2 s` that rejects force spikes/noise.

### 2.2 Umkehr — angle turning point

Umkehr is the moment the oar stops swinging toward the bow and reverses toward the
stern, i.e. `θ` reaches its per-cycle maximum:

```
t_reversal[n] = argmax_{t ∈ R[n]} θ(t)      ⇔   ω sign flip  (+ → −)
```

Equivalently the last `t` in the recovery where `ω` crosses zero from positive to
negative. This is the cleanest measurable proxy for "Abbremsen der Vorwärtsbewegung";
`t_reversal` occurs while the blade is still out, **before** `t_catch`.

> Alternative / cross-check at boat level: the boat speed reaches a local minimum near
> the catch, so `argmin v(t)` over `R[n]` is a boat-wide reversal estimate. Use the
> per-oarlock angle turning point as primary; the speed minimum as a validation signal.

### 2.3 Setzen — same as catch

`t_setzen[n] = t_catch[n]` (force onset). Kept as a separate named event because the
key coaching metric is the **gap** between reversal and catch:

```
Δ_reversal→catch[n] = t_catch[n] − t_reversal[n]      # "Zeit zwischen Umkehr und Setzen"
```

This is the placement delay: how long after reaching the front the blade actually
loads. Small is good.

### 2.4 Anrollen — recovery boat-surge onset

Anrollen ("die Beine ziehen das Boot nach vorne") is a whole-boat event: as the crew's
mass slides toward the stern, the hull surges forward, producing a positive longitudinal
acceleration bump during the recovery. Define:

```
t_anrollen[n] = first t ∈ (t_finish[n], t_reversal[n+…])
                where a_x(t) crosses upward through a_on
```

with `a_on` a small positive threshold above the recovery noise floor. Because it uses
the boat IMU it is intrinsically crew-level. If IMU quality is poor, fall back to
"onset of sustained recovery `ω < 0`" per oarlock (event #2 merged with Anrollen) and
mark Anrollen as unavailable.

---

## 3. Crew-level aggregation (multi-oarlock)

Every event above is defined per oarlock. The PO defines the stroke by **all** rowers
("wenn *alle* Ruderer ihre Hände am Körper haben"). For `m` connected oarlocks with
per-oarlock event times `{t_e^{(1)} … t_e^{(m)}}`, the crew event `T_e` is an
aggregation, configurable:

- **all-reached** (default for the finish boundary): `T_finish = max_i t_finish^{(i)}`
  — the cycle closes only when the last rower releases.
- **mean**: `T_e = mean_i t_e^{(i)}` — good for rate/ratio metrics.
- **reference rower**: `T_e = t_e^{(bow)}` — bow rower (position 1) sets the timing.

Crew **synchronisation spread** `σ_e = max_i t_e − min_i t_e` is itself a useful
coaching metric (how together the crew catches/finishes). Expose it per event.

With only two oarlocks in the current hardware, `max`/`mean` are cheap; the design must
still degrade gracefully to `m = 1`.

---

## 4. Per-cycle quantities derived from the events

Once cycle `n` is closed at `t_finish[n]`, emit (all consumed by the stroke-engine spec):

```
T_stroke[n]   = t_finish[n] − t_finish[n−1]            # stroke period  (s)
T_drive[n]    = t_finish[n] − t_catch[n]               # drive time     (s)
T_recovery[n] = t_catch[n]  − t_finish[n−1]            # recovery time  (s)
SPM[n]        = 60 / T_stroke[n]                       # strokes/minute, extrapolated
ratio[n]      = T_recovery[n] / T_drive[n]             # Freilauf : Durchzug
Δ_rev→catch[n]= t_catch[n]  − t_reversal[n]            # Umkehr → Setzen (s)
θ_catch[n]    = max θ over cycle ;  θ_finish[n] = min θ over cycle
sweep[n]      = θ_catch[n] − θ_finish[n]               # total arc (deg)
```

`SPM[n]` is exactly the PO's requirement: a value **per stroke**, extrapolated from
that stroke's period — not a rolling one-minute average.

Distance-per-stroke, power-per-stroke etc. are cycle integrals of other signals over
`T_stroke[n]` / `D[n]`; they are defined in
[`kinematics-and-derived-metrics.md`](kinematics-and-derived-metrics.md) and
[`force-power-model.md`](force-power-model.md) respectively and are attached to the same
cycle boundary so every per-stroke value shares one timeline.

---

## 5. Reference detection algorithm (per oarlock)

A hysteresis state machine over the fused `(θ, ω, F)` stream. Boat-level events
(`a_x`) are matched into the nearest open cycle.

```
state ∈ {RECOVERY, DRIVE}
on each sample (t, θ, F), with ω from §1.2:

  DRIVE:
    track running max θ? no — θ_catch was set at entry
    if F < F_off and (t − t_catch) ≥ τ_min:
        t_finish ← t
        close cycle n  →  emit per-cycle quantities (§4)
        state ← RECOVERY

  RECOVERY:
    update θ_max, t_of_θ_max                  # candidate reversal
    if ω crosses + → − : t_reversal ← t       # confirm turning point
    if a_x crosses ↑ a_on (and none yet this cycle): t_anrollen ← t
    if F > F_on:
        t_catch ← t ;  θ_catch ← θ ;  t_reversal ← t_of_θ_max (finalise)
        state ← DRIVE
```

Guards:

- **Warm-up**: the first detected finish only *starts* cycle 0; the first fully-formed
  cycle needs one catch **and** one finish.
- **Debounce**: reject cycles with `T_drive < τ_min` or `T_stroke <` `τ_stroke_min`
  (e.g. 0.7 s ⇒ SPM ≤ ~85, above any real rate).
- **Idle / paused**: if no catch occurs for `> T_idle` (e.g. 5 s) declare "not rowing";
  suppress SPM so it decays/blanks rather than reading a stale huge period.

---

## 6. Parameters (all tunable, all with physical units)

| Symbol       | Meaning                          | Default | Where set |
|--------------|----------------------------------|---------|-----------|
| threshold mode | absolute \| auto-scaled         | absolute | stroke-engine settings |
| `F_on`       | catch threshold (abs) / `k_on` (auto)  | 40 N / 0.15 | stroke-engine settings |
| `F_off`      | finish threshold (abs) / `k_off` (auto) | 20 N / 0.08 | stroke-engine settings |
| `τ_min`      | min drive duration               | 0.2 s   | stroke-engine settings |
| `τ_stroke_min` | min stroke period              | 0.7 s   | stroke-engine settings |
| `a_on`       | recovery-surge accel threshold   | tune    | stroke-engine settings |
| `T_idle`     | not-rowing timeout               | 5 s     | stroke-engine settings |
| LPF cutoff   | angle smoothing before `ω` (fs = 100 Hz) | 3–5 Hz  | fixed const |
| crew agg.    | max / mean / reference           | max     | boat-rig-config |

## 7. Open questions

1. ~~Confirm the per-oarlock sample rate.~~ **Resolved: 100 Hz** (ForceReader/AngleReader
   10 ms; AppTypes.h). LPF cutoff and `ω` step pinned to `fs = 100 Hz`.
2. ~~Absolute vs. auto-scaled thresholds?~~ **Decided: both, user-selectable** (§2.1) —
   absolute defaults with an auto-scale (`k · F_peak_recent`) toggle. Remaining: tune
   `k_on`/`k_off` and the warm-up seeding against real data.
3. Validate the angle-turning-point definition of Umkehr against the boat-speed minimum
   on real water data before locking it in. (The boat-speed signal is coarse — see the
   GPS-speed note in [kinematics §1](kinematics-and-derived-metrics.md) — so the
   per-oarlock angle turning point is the more reliable primary anyway.)
