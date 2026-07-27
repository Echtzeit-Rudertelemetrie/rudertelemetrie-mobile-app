# 22 — Auto-record cannot be turned off

**Priority:** P2 · **Effort:** S · **Area:** recording

## Problem

Any detected catch starts a recording. There is no setting to disable this and
no indication that it is about to happen. Carrying the boat, testing an oarlock
on the rack, or a crew warming up before the piece all trigger a session, and
each one is saved to History as real training data.

The timeouts are compile-time constants, so a user whose usage does not match
the defaults has no recourse: `_autoStopIdle` is 20 s, which ends a session
during a normal pause between pieces.

## Evidence

- `lib/services/recording/recording_session.dart:119-124` — `onRowingDetected`
  starts recording whenever `_autoArmed`.
- `lib/services/recording/recording_session.dart:26` —
  `static const _autoStopIdle = Duration(seconds: 20);`
- `lib/services/stroke/stroke_engine.dart:130` — every catch calls
  `session?.onRowingDetected()`.
- `lib/screens/stroke_settings_screen.dart` — exposes threshold mode and crew
  aggregation only; no recording settings.
- `_autoArmed` is only re-armed by `reset()`
  (`recording_session.dart:107-117`), so a user who manually stops gets
  different behaviour afterwards with no visible explanation.

## Fix

1. Add a recording settings section (own screen, or a section in Stroke
   Detection) with:
   - auto-start on detected rowing (on/off),
   - auto-stop idle timeout (slider, e.g. 10–120 s),
   - a minimum session duration below which a session is discarded rather than
     saved — this alone removes most accidental recordings.
2. Persist these alongside the other settings; `StrokeSettings` is the natural
   home, or a sibling `RecordingSettings` `ChangeNotifier`.
3. Make the auto-arm state visible in the session control so the user can tell
   whether auto-start is currently possible.
4. Pair with task 15 so an auto-start is announced.

## Acceptance criteria

- [ ] Auto-start can be disabled; with it off, only the record button starts a
      session.
- [ ] The auto-stop timeout is user-adjustable and persisted.
- [ ] Sessions shorter than the configured minimum are discarded, not saved.
- [ ] The UI shows whether auto-start is currently armed.
