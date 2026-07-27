# 04 — Every chart is wiped whenever the dashboard changes at all

**Priority:** P1 · **Effort:** M · **Area:** dashboard

## Problem

`_DashboardScreenState.didChangeDependencies` clears the entire bound-visualizer
cache. `didChangeDependencies` fires on *any* watched provider notification —
toggling edit mode, dragging a tile, resizing, a preset swap, a new source
appearing. Each clear rebinds every visualizer, which recreates the stream
transformers and **discards all accumulated chart history**.

Moving one tile blanks every chart on the dashboard and restarts their time
windows from zero.

## Evidence

- `lib/screens/dashboard_screen.dart` — `didChangeDependencies()` calls
  `_boundCache.clear()` with the comment "Clear stale cache entries whenever the
  dashboard model notifies", which is exactly the over-broad behaviour.
- The cache key already encodes everything that should force a rebind:
  `'${config.id}_${visualizerKey}_${sourceKeys.join(',')}_${_paramsSignature(params)}'`.
- Tiles drop their buffers on rebind:
  `chart_tile.dart:53-60` `_resubscribe()` sets `_points = []`.

## Fix

Stop clearing wholesale. The key already changes when the tile's configuration
changes, so a stale entry can only arise when a *source instance* behind a key
is replaced (device reconnect) or a tile is deleted.

1. Remove the `didChangeDependencies` override.
2. Include source identity in the cache key, e.g. append
   `identityHashCode(source)` for each resolved source so a reconnected device
   produces a different key.
3. Evict entries whose `config.id` is no longer in `model.layout` (do this in
   `build`, after computing the live id set) so the map cannot grow unbounded.

## Acceptance criteria

- [ ] Dragging, resizing or entering/leaving edit mode leaves chart history
      intact.
- [ ] Swapping dashboard presets and swapping back preserves the charts of
      tiles that were untouched.
- [ ] Changing a tile's visualizer, source or params still rebinds it.
- [ ] A device disconnecting and reconnecting rebinds affected tiles.
- [ ] Deleting a tile removes its cache entry (assert cache size in a test).
