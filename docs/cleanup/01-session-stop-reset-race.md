# 01 — Stop→Reset race deletes the session that was just saved

**Priority:** P0 · **Effort:** S · **Area:** recording

## Problem

`RecordingSession` fires both store calls with `unawaited`, so `stop()` and
`reset()` can run against the store concurrently. `abortSession()` then deletes
the directory of the session `finishSession()` is still writing.

Tapping stop and then reset in quick succession destroys the CSV of a finished
session while leaving its entry in `index.json` — the user sees a session in
History that has no data.

## Evidence

- `lib/services/recording/recording_session.dart:96-117` — `_stop()` does
  `unawaited(store?.finishSession(...))`, `reset()` does
  `unawaited(store?.abortSession())`.
- `lib/services/recording/session_store.dart:152-170` — `finishSession` awaits
  `_teardownSubscriptions()` before clearing `_active`; `abortSession` only
  returns early when `_active == null`, otherwise it runs
  `dir.delete(recursive: true)`.
- `lib/components/recording/session_control.dart:53-65` — the reset button
  appears next to stop, and only once the session has stopped: precisely the
  window in which the race is reachable.

The same race exists on record-immediately-after-stop, since `beginSession`
starts with `await abortSession()`.

## Fix

Serialise all store mutations so they cannot interleave. Chain them on a single
future held by `FileSessionStore`:

```dart
Future<void> _queue = Future.value();

Future<T> _serial<T>(Future<T> Function() op) {
  final result = _queue.then((_) => op());
  _queue = result.then((_) {}, onError: (_) {});
  return result;
}
```

Route `beginSession`, `finishSession` and `abortSession` through `_serial`.
Additionally make `abortSession` a no-op for a session that has already been
finished — track the finished id, don't rely only on `_active`.

## Acceptance criteria

- [ ] `stop()` immediately followed by `reset()` leaves the finished session's
      `session.csv` and `session.json` intact and listed in History.
- [ ] `stop()` immediately followed by `start()` produces two independent,
      complete sessions.
- [ ] `reset()` on a session that was never stopped still discards it fully.
- [ ] Regression test in `test/recording_session_test.dart` driving
      stop-then-reset against a fake store, asserting no delete reaches the
      finished id.
