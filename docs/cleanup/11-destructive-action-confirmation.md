# 11 — Irreversible session delete is a single unguarded tap

**Priority:** P1 · **Effort:** S · **Area:** history

## Problem

The trash icon in the session detail header deletes the session directory
immediately: no confirmation, no undo, no way to recover a training session that
took an hour to record. The icon sits directly beside the share icon in the
header, exactly where a mis-tap is likely.

## Evidence

- `lib/screens/session_detail_screen.dart:60-63` — `FHeaderAction(icon:
  Icon(FIcons.trash2), onPress: _delete)` next to the share action.
- `lib/screens/session_detail_screen.dart:43-46` — `_delete` calls
  `deleteSession` then pops, with nothing in between.
- `lib/services/recording/session_store.dart:197-205` — `deleteSession` does
  `dir.delete(recursive: true)`.

## Fix

1. Confirm before deleting, using Forui's dialog so it matches the app's styling
   (`showFDialog` / `FDialog`). Name what is being deleted: date, duration and
   distance, so the user can tell they have the right session.
2. Make the confirm action visually destructive and the cancel action the
   default focus.
3. Consider a soft delete: move the directory to a `trash/` folder purged after
   N days, which makes recovery possible at negligible cost.
4. Apply the same confirmation to any other irreversible action added later —
   for dashboard presets, deleting the last one is already blocked in
   `DashboardModel.deletePreset`, but a multi-tile preset deserves a confirm
   dialog too.

## Acceptance criteria

- [ ] Deleting a session requires an explicit confirmation naming the session.
- [ ] Cancelling leaves the session and its files untouched.
- [ ] Confirming removes the directory and the index entry, and pops the screen.
- [ ] Deleting a non-empty dashboard preset also confirms first.
