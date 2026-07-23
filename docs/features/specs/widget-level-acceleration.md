# Spec: Spirit-level & acceleration widget

**Importance:** Nice-to-have · **Complexity:** Low–Medium
**Depends on:** `Acceleration X/Y/Z` sources (exist) · **Refs:** PO links
(t1p.de/q8bpv, the YouTube bubble-level clip).
**Math:** [`../math/kinematics-and-derived-metrics.md`](../math/kinematics-and-derived-metrics.md) §6.

## What

A `CustomPaint` tile showing boat attitude like a spirit level plus a live acceleration
indicator: a bubble/crosshair for roll & pitch and an arrow (or bar) for longitudinal
surge/check.

## Signals & math

- **Roll / pitch** from the low-passed gravity vector: `roll = atan2(a_y, a_z)`,
  `pitch = atan2(−a_x, √(a_y²+a_z²))` (math §6). Heavy LPF (cutoff < 0.5 Hz) so rowing
  acceleration doesn't jitter the level.
- **Acceleration indicator**: the *un*filtered longitudinal `a_x` (surge on drive, check
  on recovery) as an arrow whose length/direction tracks `a_x`. This is the "check" a
  crew feels each stroke.

## UI

- `LevelTile` (new tile type, bypasses the visualizer pipeline — subscribes to the three
  accel sources directly, like `ValueTile`).
- Bubble moves within a circle for (roll, pitch); tilt beyond a range clamps to the rim.
- Optional numeric roll/pitch degrees under the bubble.
- Colour the bubble when near-level (green) vs. tilted (amber) for glanceability.

## Edge cases

- IMU axes are fixed by the mount orientation, units **m/s²** (`ImuData`), so no
  g-conversion: `acc_z` up, `acc_x` longitudinal, `acc_y` lateral.
- At rest `|g|` should ≈ 9.81; if far off, the accel isn't gravity-referenced — show a
  warning instead of a wrong level.
- The boat IMU currently emits simulated values (`SimData::imu`), so the widget visualises
  simulated attitude for now — flag it as "sim" so it isn't mistaken for real attitude.

## Open questions
1. IMU units are m/s² and axes are fixed in firmware; the boat IMU currently streams
   simulated values.
2. Do we also want a gyro? Only accel is in the boat packet.
