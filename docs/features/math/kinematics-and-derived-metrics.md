# Math: Kinematics & derived boat metrics

Status: **spec / math only** — no implementation yet.
Consumes: boat `Speed` (m/s), GPS position (lat/lon — *to be exposed*, see
[`../specs/widget-map.md`](../specs/widget-map.md)), `Acceleration X/Y/Z` (m/s²), and the
recording clock. Produces: the low-complexity numeric readouts in
[`../specs/recording-session.md`](../specs/recording-session.md).

These are the "essential values" that are simple functions of existing streams. Grouped
so the trivial ones aren't lost among the hard ones.

---

## 1. Speed and pace

```
v            = Speed stream                       (m/s)
speed_kmh    = v · 3.6                             (km/h)
pace_s_500   = 500 / v                             (seconds per 500 m)   for v > 0
pace_mmss    = format(pace_s_500)                  → "m:ss / 500m"
```

Pace is undefined at `v = 0`; blank it (or show `—:—`) below a small speed floor
(e.g. `v < 0.3 m/s`).

> **GPS speed is integer-truncated in firmware — derive `v` from position instead.**
> Confirmed against `rowing_boat`: `Gps.cpp` casts `TinyGPSPlus.speed.mps()` (a float,
> m/s) into an `int16_t`, so the boat only ever transmits **whole m/s** (1 m/s = 3.6 km/h
> steps — far too coarse for pace). Therefore:
>
> - **Primary speed source = GPS position** (`v = Δs/Δt` from the haversine step, §2.2),
>   which uses the full lat/lon resolution (×1e6 degrees ≈ 0.11 m).
> - The firmware `Speed` stream is kept only as a coarse fallback when position is stale.
> - A cheap firmware fix (send `speed·100` as cm/s) would make the direct value usable;
>   flagged as a `rowing_boat` improvement, not required for the app.
>
> Every speed/pace/distance number below assumes the position-derived `v`.

---

## 2. Distance travelled ("gefahrene Kilometer")

Two independent estimators — implement both, prefer GPS-haversine for absolute distance,
use speed-integration as a smooth fallback when GPS fix is poor.

### 2.1 Integrate speed (smooth, always available)

Trapezoidal integration over samples since recording start:

```
s_int(t) = Σ_k  ½ · (v[k] + v[k−1]) · (t[k] − t[k−1])         (m)
distance_km = s_int / 1000
```

### 2.2 Haversine over GPS fixes (absolute, needs position)

For consecutive valid fixes `(φ₁,λ₁) → (φ₂,λ₂)` (radians), Earth radius `R = 6 371 000 m`:

```
a = sin²(Δφ/2) + cos φ₁ · cos φ₂ · sin²(Δλ/2)
Δs = 2R · atan2(√a, √(1−a))
s_gps(t) = Σ Δs   over fixes with GpsSample.valid == true
```

Reject fixes with `valid == false` or implausible jumps (`Δs / Δt > v_max`, e.g. 12 m/s)
to suppress GPS glitches. Instantaneous speed can also be recovered as `Δs/Δt` if the
firmware speed proves unusable.

---

## 3. Distance per stroke ("Zurückgelegte Strecke pro Schlag")

Attached to stroke cycle `n` from [stroke-detection §4](stroke-detection.md):

```
s_stroke[n] = ∫_{cycle n} v dt  =  s_int(t_finish[n]) − s_int(t_finish[n−1])
            ≈ v̄[n] · T_stroke[n]
```

i.e. how far the boat travels per full stroke. `v̄[n]` is the cycle-mean speed. A high
distance-per-stroke at a given rate indicates effective boat run.

---

## 4. Elapsed time ("Zeit seit Beginn der Aufzeichnung")

```
elapsed(t) = t − t_recording_start
```

Owned by the recording session (start/stop/reset), formatted `h:mm:ss`. Distinct from
each `DataSource.startTime`; the session clock is a single shared origin so every metric
shares one timeline.

---

## 5. Running averages ("Durchschnittswerte … von allen Werten, bei denen es Sinn ergibt")

A **generic** time-weighted mean of any stream since recording start:

```
avg_X(t) = ( Σ_k ½·(X[k]+X[k−1])·Δt_k ) / ( t − t_start )
```

Time-weighting (not sample count) makes it robust to irregular sample rates. Applies to:
speed, power, force, SPM, ratio, distance-per-stroke, blade efficiency — anything where a
mean is meaningful. It should be implemented **once** as a reusable derived-stream
wrapper (recording-session spec), not per metric.

Metrics where a plain mean is **not** meaningful (skip or use a different reduction):
raw angle (oscillates around 0 → mean ≈ 0), lateral force, acceleration components.
For those, expose peak / RMS instead where useful.

---

## 6. Tilt from acceleration (spirit level)

For the level widget ([`../specs/widget-level-acceleration.md`](../specs/widget-level-acceleration.md)),
static tilt from the gravity vector in the boat frame `(a_x, a_y, a_z)`:

```
roll  = atan2( a_y , a_z )                          # port/starboard lean
pitch = atan2( −a_x , √(a_y² + a_z²) )              # bow/stern trim
|g|   = √(a_x² + a_y² + a_z²)                        # should ≈ 9.81 at rest
```

Dynamic (rowing) acceleration corrupts this; low-pass `a` heavily (cutoff < 0.5 Hz) for
the *level* reading, and separately show the *un*filtered longitudinal `a_x` as the
"acceleration" indicator (the surge/check per stroke).

**Units & axes (from `rowing_boat`):** `ImuData` documents `acc_x/y/z` in **m/s²**
(float32), so no g→m/s² conversion is needed and the `|g| ≈ 9.81` rest check applies
directly. But the boat IMU is **currently simulated** (`SimData::imu`) and no real driver
exists yet — the simulation uses `acc_z = 9.81` (gravity up), `acc_x` = longitudinal
surge, `acc_y` = small lateral. Use that mapping
(`roll = atan2(a_y, a_z)`, `pitch = atan2(−a_x, √(a_y²+a_z²))`) as the working default; the
real axis→(roll, pitch, longitudinal) assignment and signs are a **fixed property of the IMU
mounting, read off firmware once a real hub IMU (e.g. LSM6DS/MPU) is wired in — not an
app-side calibration**.

---

## 7. Summary of outputs and their complexity

| Metric | Formula ref | Depends on | Complexity |
|--------|-------------|------------|------------|
| speed km/h, pace /500m | §1 | Speed | trivial |
| elapsed time | §4 | session clock | trivial |
| distance / km | §2 | Speed or GPS pos | low |
| running average (generic) | §5 | any stream + session | low |
| distance per stroke | §3 | Speed + stroke engine | medium |
| tilt / level | §6 | Accel | low–medium |
