# 13 — Crew metrics freeze permanently if one oarlock stops producing cycles

**Priority:** P1 · **Effort:** M · **Area:** stroke engine

## Problem

`StrokeEngine._onCycle` only publishes a crew stroke once **every** bound
oarlock has a pending cycle. If one rower stops rowing, one oarlock's detector
rejects its cycles (spurious catch, rate outside `[τ_min, idleTimeout]`), or one
device streams intermittently, `_pending` never completes.

Every crew metric — stroke rate, count, drive:recovery ratio, catch/finish
angle, sweep, crew sync, distance per stroke — then freezes indefinitely, with
no indication on the dashboard that the numbers have gone stale rather than
simply being constant.

## Evidence

- `lib/services/stroke/stroke_engine.dart:134-137`:
  ```dart
  _pending[cycle.oarlockKey] = cycle;
  final active = _bindings.keys.toSet();
  if (!active.every(_pending.containsKey)) return;
  ```
- `lib/services/stroke/oarlock_stroke_detector.dart:104-120` — a cycle is
  dropped entirely when `strokeSeconds` falls outside
  `[tauMinStroke, idleTimeout]`, so a legitimately slow or paused rower
  contributes nothing.
- `_pending` entries are overwritten but never expire — there is no staleness
  bound anywhere in the class.

## Fix

1. **Expire stale pending cycles.** Drop entries older than a bound (e.g.
   `2 × idleTimeout`) and publish with the oarlocks that did report, marking the
   result as partial.
2. **Publish on a quorum with a deadline.** When the first cycle of a group
   arrives, start a short window (e.g. 1.5 s); publish whatever has arrived when
   it closes. This matches how a crew stroke actually completes — finishes are
   spread, not simultaneous.
3. **Expose participation.** Include the contributing oarlock count in
   `CrewStroke` so the UI can show "3 of 4" and the user understands a partial
   reading.
4. **Surface staleness in tiles.** A value tile whose source has not emitted for
   several seconds should dim or show a stale marker rather than displaying an
   old number as if it were live.

## Acceptance criteria

- [ ] With two oarlocks bound and one stopping, crew stroke rate continues to
      update from the active one within a few seconds.
- [ ] Resuming with both oarlocks returns to full-crew aggregation.
- [ ] `finishSpread` / crew sync is only reported when at least two oarlocks
      contributed.
- [ ] Tests in `test/stroke_engine_test.dart` for: one oarlock silent, one
      oarlock intermittent, oarlock disconnecting mid-stroke.
