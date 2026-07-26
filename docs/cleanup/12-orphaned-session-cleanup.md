# 12 — Killed recordings leave invisible directories that grow forever

**Priority:** P1 · **Effort:** S · **Area:** recording

## Problem

A session directory is created and written to as recording proceeds, but the
`index.json` entry is only appended in `finishSession`. If the app is killed
mid-recording — force quit, OS reclaim, battery death, all plausible on the
water — the directory keeps a partial CSV that is:

- never listed in History (nothing reads the directory listing),
- never deleted,
- potentially large (100 Hz × many sources over a long piece).

Storage grows with no user-visible cause and no way to reclaim it from inside
the app.

## Evidence

- `lib/services/recording/session_store.dart:113-122` — `beginSession` creates
  the directory and opens the sink.
- `lib/services/recording/session_store.dart:152-160` — `_appendToIndex` runs
  only in `finishSession`.
- `lib/services/recording/session_store.dart:186-195` — `listSessions` reads
  only `index.json`, never the directory.
- Nothing calls `RecordingSession.dispose()` or closes the sink on app
  termination, so the CSV's tail is also unflushed.

## Fix

1. **Startup sweep.** On store construction, list `sessions/` and reconcile
   against `index.json`:
   - directory present but not indexed and older than the current run →
     recoverable orphan;
   - offer recovery (synthesise a summary from the CSV: duration from last
     `elapsed_ms`, distance if a `Distance` series exists) or delete.
   Recovering is preferable — the data is the user's training.
2. **Write the info eagerly.** Write `session.json` with the *start* info at
   `beginSession` and overwrite it with the full summary at `finishSession`.
   Then an orphan is self-describing.
3. **Flush periodically.** Flush the sink every few seconds so a kill loses at
   most a moment of data.
4. Add an app-lifecycle observer that finalises a recording on
   `AppLifecycleState.detached`.

## Acceptance criteria

- [ ] Killing the app mid-recording and restarting surfaces the partial session
      (recovered or offered for deletion), not silence.
- [ ] No unreferenced directories remain under `sessions/` after a sweep.
- [ ] A recovered session opens in the detail screen with a usable replay.
- [ ] Test covering: directory present, index entry absent.
