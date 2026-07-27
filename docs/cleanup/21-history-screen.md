# 21 — History screen lacks basic list affordances

**Priority:** P2 · **Effort:** S · **Area:** history

## Problem

The session list supports exactly one interaction: tap to open. Missing:

- **Delete from the list.** Removing a session requires opening it and finding
  the trash icon in the header.
- **Pull to refresh.** The list only reloads on `initState` and after returning
  from a detail screen, so a session finished while History is open never
  appears.
- **Any filtering or grouping.** Sessions are a flat, undated list; after a few
  weeks of training, finding a particular outing means scrolling.
- **Useful summary.** Rows show duration, distance and start mode. Start mode
  ("manual"/"auto") is an implementation detail; average pace or stroke rate
  would be worth the space.

## Evidence

- `lib/screens/history_screen.dart:64-78` — `ListView.builder` with a tap
  handler and nothing else.
- `lib/screens/history_screen.dart:20-28` — `_load()` only from `initState`,
  re-run via `setState(_load)` after a pop.
- `lib/screens/history_screen.dart:110-116` — the subtitle:
  `'${formatElapsed(...)} · ${formatDistance(...)} · ${startMode.name}'`.
- `lib/services/recording/session_record.dart:19-32` — `SessionSummary` already
  carries `averages` and `peaks`, currently unused in the list.

## Fix

1. Swipe-to-delete with confirmation (share the dialog from task 11) and an
   undo window.
2. `RefreshIndicator` for pull-to-refresh.
3. Group rows by day with sticky date headers; consider a date-range filter once
   the list is long.
4. Replace start mode in the subtitle with average pace (per task 16's pace
   formatter) or average stroke rate. Keep start mode in the detail screen.
5. Show total distance/time for the visible period in the header.

## Acceptance criteria

- [ ] A session can be deleted from the list, with confirmation and undo.
- [ ] Pull-to-refresh reloads the list.
- [ ] Rows are grouped by day.
- [ ] The subtitle shows a training-relevant metric rather than start mode.
