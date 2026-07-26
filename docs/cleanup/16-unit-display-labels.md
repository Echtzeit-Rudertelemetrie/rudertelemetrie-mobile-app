# 16 — Units display as raw enum names; pace and elapsed are unreadable

**Priority:** P2 · **Effort:** S · **Area:** presentation

## Problem

`Unit` carries no display label, so the UI prints the Dart identifier directly.
Tiles literally read `kmh`, `mps2`, `pct`, `deg`, `spm`, `radps`, `mN`. It looks
unfinished and, at a glance from a moving boat, `mps` vs `mps2` is genuinely
ambiguous.

Two related formatting problems:

- **Pace** is stored in seconds and shown raw — `128.5` instead of `2:08`.
  Pace per 500 m is the single most-read number in rowing; nobody reads it in
  decimal seconds.
- **Elapsed** always prints an hours component: `0:05:23` for a five-minute
  piece.

## Evidence

- `lib/constants/unit.dart` — a bare enum, no labels.
- `lib/components/dashboart_tiles/value_tile.dart:82` —
  `widget.visualizer.units.y.name`.
- `lib/components/dashboart_tiles/chart_tile.dart:87-89,154` — `.name` in axis
  and header labels.
- `lib/components/dashboart_tiles/bar_tile.dart:113` — same.
- `lib/dashboard/add_widget_sheet.dart:474` — source list shows
  `dataSource.unit.name`.
- `lib/services/recording/recording_session.dart:61` — `'Pace (/500m)'`
  registered as `Unit.s`.
- `lib/components/recording/session_control.dart:6-9` — `formatElapsed` always
  emits `h:mm:ss`.

## Fix

1. Give `Unit` a display label:
   ```dart
   enum Unit {
     kmh('km/h'), mps('m/s'), mps2('m/s²'), deg('°'), pct('%'),
     radps('rad/s'), spm('spm'), N('N'), W('W'), /* … */;
     final String label;
     const Unit(this.label);
   }
   ```
   Replace every `unit.name` used for display with `unit.label`. Keep `.name`
   for persistence keys so saved data is unaffected.
2. Add a pace formatter (`m:ss`) and use it wherever a pace source is displayed.
   The value tile needs to know the source is a pace — either a dedicated
   `Unit.pace` or a per-source formatter hint.
3. `formatElapsed`: drop the hours component below one hour (`5:23`), keep
   `h:mm:ss` above.

## Acceptance criteria

- [ ] No screen displays a raw enum identifier as a unit.
- [ ] Pace reads as `2:08 /500m`.
- [ ] A 5-minute session shows `5:23`; a 70-minute one shows `1:10:04`.
- [ ] Persisted files are unchanged (labels are display-only).
- [ ] Unit tests for the pace and elapsed formatters, including the hour
      boundary.
