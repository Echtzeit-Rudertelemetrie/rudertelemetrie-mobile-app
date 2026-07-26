# 02 — No error handling anywhere in `lib/`

**Priority:** P0 · **Effort:** M · **Area:** cross-cutting

## Problem

`grep -rn "try {" lib/` returns nothing (the only hit is the substring in
`class VisualizerRegistry {`). Every `jsonDecode`, `readAsString`, file delete
and BLE call is unguarded, and no `FutureBuilder` in the app handles
`snapshot.hasError`.

The user-visible consequence is worse than a crash: a truncated `index.json`
(app killed mid-write) leaves History spinning forever with no way to recover
from inside the app.

## Evidence

- `lib/screens/history_screen.dart:44` — `if (!snapshot.hasData)` shows a
  spinner; an error snapshot also has no data, so the spinner never resolves.
- `lib/screens/session_detail_screen.dart:108` — same pattern for the replay.
- `lib/services/recording/session_store.dart:186-195` — `listSessions` does
  `jsonDecode(await file.readAsString())` unguarded.
- `lib/services/recording/session_record.dart:47-57` — `fromJson` hard-casts
  (`json['id'] as String`), so one malformed entry kills the whole list.
- `lib/services/rig/boat_config_store.dart:34-60` — a corrupt
  `boat_config.json` throws inside the provider's `create`.

`FileDashboardPresetStore` (added with the preset feature) already follows the
intended pattern — use it as the reference.

## Fix

1. **Stores swallow and degrade.** Wrap load/save in `try`/`catch`; on a read
   failure return "nothing saved" rather than throwing. Move a corrupt file
   aside (`index.json.corrupt`) so it is recoverable for debugging but never
   blocks startup.
2. **Per-entry tolerance.** `listSessions` should skip entries that fail to
   parse instead of failing the whole list. Make `SessionSummary.fromJson`
   return `null` on bad input, or wrap each entry.
3. **UI handles errors.** Every `FutureBuilder` gets a `snapshot.hasError`
   branch with a readable message and a Retry button.
4. **BLE.** Replace `catchError((_) => _forgetDevice(...))` with handling that
   also reports the failure (see task 15).

## Acceptance criteria

- [ ] Corrupting `index.json` on device still lets History open, showing either
      the surviving sessions or an empty state with an error notice.
- [ ] Corrupting `boat_config.json` does not prevent app start; rig setup opens
      with defaults.
- [ ] All `FutureBuilder`s in `lib/screens/` handle `hasError`.
- [ ] Tests cover: malformed index JSON, one bad entry among good ones, and a
      missing file.
