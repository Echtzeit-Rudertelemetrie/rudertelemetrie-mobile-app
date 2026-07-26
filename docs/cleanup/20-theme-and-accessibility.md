# 20 — Hardcoded colours and sunlight-hostile typography

**Priority:** P2 · **Effort:** M · **Area:** presentation

## Problem

**Colours.** `Color(0xFFF45866)`, `Colors.white54`, `Colors.white38`,
`Color(0xFF1a1d30)` and friends are pasted literally across roughly twenty
files, even though `getTheme()` already builds a proper Forui theme with that
accent. Consequences: a palette change is a twenty-file sweep, a light theme is
impossible, and the shades have already drifted (`white54` vs `white38` vs
`white24` used interchangeably for the same role).

**Legibility.** Chart and tile labels are 8–11 px. This app is read at arm's
length, in direct sunlight, from a moving boat. Chips use 6 px vertical padding,
well under the 44 px minimum tap target — hard to hit with wet hands.

## Evidence

- `lib/utils/startup_util.dart:20-23` — the accent is already in the theme as
  `primary`.
- Hardcoded accent, non-exhaustively:
  `dashboard_screen.dart`, `dashboard_grid.dart`, `dashboard_widget_tile.dart`,
  `add_widget_sheet.dart`, `stream_selector_sheet.dart`, `preset_sheet.dart`,
  `sheet_scaffold.dart`, `session_control.dart`, `history_screen.dart`,
  `session_detail_screen.dart`, `boat_setup_screen.dart`, `rig_setup_screen.dart`,
  `stroke_settings_screen.dart`, and every tile in `components/dashboart_tiles/`.
- Font sizes: `chart_tile.dart:200,224` (`fontSize: 8`), `bar_tile.dart:143,192`
  (8), tile headers at 10, most labels at 11–12.
- Tap targets: `boat_setup_screen.dart:142` — `vertical: 6` chips;
  `stroke_settings_screen.dart:119` — `vertical: 10`.
- No `Semantics` anywhere in `lib/`.

## Fix

1. Define semantic tokens once (accent, surface, label, muted label, grid line,
   danger) sourced from the Forui theme, and replace the literals. Do this
   file-group by file-group to keep diffs reviewable.
2. Raise the display type scale: no on-screen text below ~12 px, tile values
   large and high-contrast. Consider an explicit "on-water" scale rather than
   relying on the default.
3. Bring interactive elements to a 44 px minimum hit area (padding or
   `MaterialTapTargetSize`).
4. Respect the system text-scale factor and verify no overflow at the largest
   setting.
5. Add `Semantics` labels to the icon-only controls (record, stop, reset, edit
   mode, preset switcher, tile handles).

## Acceptance criteria

- [ ] `grep -rn "0xFFF45866" lib/` returns only the theme definition.
- [ ] No user-facing text below 12 px.
- [ ] All interactive targets ≥ 44 px.
- [ ] The app is usable with the system font scale at maximum without overflow.
- [ ] Icon-only buttons are labelled for screen readers.
