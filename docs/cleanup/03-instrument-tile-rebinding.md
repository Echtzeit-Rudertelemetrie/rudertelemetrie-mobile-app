# 03 — Level and Map tiles never rebind to sources that appear later

**Priority:** P1 · **Effort:** S · **Area:** dashboard tiles

## Problem

`LevelTile` and `MapTile` resolve their data sources once in `initState` and
never listen to the registry. `_buildInstrument` hands them the stable registry
object, so they are not rebuilt when sources change either.

Add a Level or Map tile before the boat is connected and it stays dead
permanently — "No boat IMU" / empty map — even after the boat connects. The user
has to delete and re-add the tile, with no hint that this is the remedy.

## Evidence

- `lib/components/dashboart_tiles/level_tile.dart:41,67-89` — `_bind()` called
  only from `initState`; returns early when the three `Acceleration *` sources
  are absent and is never retried.
- `lib/components/dashboart_tiles/map_tile.dart:39,56-59` — same shape for
  `Latitude`/`Longitude`.
- `lib/screens/dashboard_screen.dart` `_buildInstrument` — passes
  `context.read<DataSourceProviderModel>().registry`, a stable instance.

Two components in the codebase already do this correctly and should be the
model:

- `lib/services/recording/recording_session.dart:64` —
  `registry.addListener(_bindGpsSources)`.
- `lib/components/dashboart_tiles/boat_schematic_tile.dart:78-80` —
  `_ensureSubscribed` runs in `build`.

## Fix

Give both tiles a registry listener that re-runs binding when the source set
changes, cancelling and replacing existing subscriptions. Extract the shared
"find source by name prefix, resubscribe on registry change" logic — it is now
duplicated in four places (`RecordingSession._find`, `LevelTile._find`,
`MapTile._find`, `BoatSchematicTile._angleFor`).

Suggested: a small `SourceBinder` helper in
`lib/services/data_processing/` that takes a registry plus a list of name
prefixes and exposes a rebind callback.

## Acceptance criteria

- [ ] Adding a Level tile with no device connected, then connecting the boat,
      makes the tile come alive without re-adding it.
- [ ] Same for the Map tile.
- [ ] Disconnecting the boat returns the tiles to their empty state rather than
      freezing on the last value.
- [ ] Subscriptions are cancelled on rebind and on dispose (no leak on repeated
      connect/disconnect cycles).
