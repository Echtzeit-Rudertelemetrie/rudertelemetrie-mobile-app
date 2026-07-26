# 14 — The screen sleeps mid-outing

**Priority:** P2 (but highest value-to-effort in the backlog) · **Effort:** XS
· **Area:** platform

## Problem

Nothing keeps the display awake. The phone is mounted in the boat and untouched
for the whole piece, so the OS dims and locks it on the default timeout — the
live dashboard, which is the entire point of the app, goes dark exactly when it
is being used.

The workaround (raising the system screen timeout globally) is a poor ask of the
user and drains the battery outside the app too.

## Evidence

- No wakelock dependency in `pubspec.yaml`.
- No `WidgetsBinding` / platform channel keeping the screen on anywhere in
  `lib/`.
- `lib/services/recording/recording_session.dart:70` — `isRecording` already
  gives a clean signal for when the screen must stay on.

## Fix

1. Add `wakelock_plus` to `pubspec.yaml`.
2. Enable while a session is recording, disable when it stops — driven off
   `RecordingSession` state so it needs no user action:
   ```dart
   WakelockPlus.toggle(enable: session.isRecording);
   ```
3. Consider also keeping it on while the dashboard is foregrounded with a device
   connected, since users watch live data before starting a recording. Make that
   a setting if battery is a concern.
4. Always release on dispose and when the app is backgrounded.

## Acceptance criteria

- [ ] The screen stays on for the full duration of a recording without touch
      input.
- [ ] The wakelock is released when the recording stops.
- [ ] The wakelock is released when the app is backgrounded or closed (verify no
      battery drain after leaving the app).
- [ ] Behaviour verified on both Android and iOS.
