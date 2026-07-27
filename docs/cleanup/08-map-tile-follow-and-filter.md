# 08 — Map tile fights the user and rejects legitimate movement

**Priority:** P1 · **Effort:** S · **Area:** dashboard tiles

## Problem

Two independent defects in `MapTile`:

1. **Forced recentre.** The controller moves to the newest fix on *every*
   update, so panning ahead to look at the course is impossible — the map snaps
   back on the next fix.
2. **Distance-based glitch gate.** Fixes more than 50 m from the previous point
   are dropped. That is a *distance* threshold applied to an interval of unknown
   length: at 5 m/s with a 15 s gap between fixes (weak signal, tunnel, bridge),
   75 m of real travel is rejected. Because `_track.last` then never advances,
   every subsequent fix is measured against the same stale point and **the track
   dies permanently**.

## Evidence

- `lib/components/dashboart_tiles/map_tile.dart:78-82` — unconditional
  `_controller.move(fix, _controller.camera.zoom)` inside `_addFix`.
- `lib/components/dashboart_tiles/map_tile.dart:26` —
  `static const _maxJumpMeters = 50.0`.
- `lib/components/dashboart_tiles/map_tile.dart:67-75` — a rejected fix returns
  early without updating any reference point.

`GpsKinematics` already models this correctly with a speed gate:
`lib/services/kinematics/gps_kinematics.dart:60` —
`maxPlausibleSpeedMps = 12.0`.

## Fix

1. **Follow mode.** Default on; disengage when the user pans or zooms (listen to
   `MapEventMove` with a user source). Show a small "recentre" button when
   disengaged and re-enable follow on tap.
2. **Speed gate.** Replace the fixed distance with
   `haversine / Δt > maxPlausibleSpeedMps`, reusing
   `GpsKinematics.maxPlausibleSpeedMps` so the map and the distance estimator
   agree. This requires keeping the timestamp of the last accepted fix.
3. **Never dead-end.** After N consecutive rejections, accept the fix and start
   a new track segment rather than rejecting forever.

## Acceptance criteria

- [ ] Panning the map keeps the chosen viewport until the user recentres.
- [ ] A 15 s gap in fixes at normal boat speed does not break the track.
- [ ] A genuine GPS teleport (km-scale jump) is still rejected.
- [ ] The track resumes after a prolonged signal loss.
