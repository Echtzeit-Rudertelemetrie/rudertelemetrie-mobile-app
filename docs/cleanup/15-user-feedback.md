# 15 — Nothing ever tells the user what happened

**Priority:** P2 · **Effort:** S · **Area:** cross-cutting UX

## Problem

`FToaster` is installed at the root of the widget tree and **never used once**.
Significant events happen with no acknowledgement at all:

- a session auto-starts because rowing was detected;
- a session auto-stops after the idle timeout and is saved;
- a device connects, drops, or fails to connect;
- an export completes (or finds no files and silently returns);
- a rig becomes invalid and force/power sources disappear.

The user cannot tell the difference between "working" and "broken", which is
particularly bad on the water where they cannot investigate.

## Evidence

- `lib/main.dart:64` — `FToaster(child: FTooltipGroup(child: child!))`, never
  referenced again anywhere in `lib/`.
- `lib/services/recording/recording_session.dart:121-124` — `onRowingDetected`
  starts recording silently.
- `lib/services/recording/recording_session.dart:163-168` — `_onTick`
  auto-stops silently.
- `lib/screens/session_detail_screen.dart:36-41` — `_export` returns silently
  when `paths.isEmpty`.
- `lib/services/bluetooth/bluetooth_manager.dart:105` — connect failures are
  swallowed by `catchError`.

## Fix

1. Introduce a thin app-level notification service so services (which have no
   `BuildContext`) can raise messages that the UI presents via `FToaster`. A
   `ChangeNotifier` holding a short queue of messages, watched near the root, is
   enough — do not scatter `context` into the service layer.
2. Emit for at minimum:
   - session auto-started / auto-stopped and saved (with duration + distance);
   - device connected / disconnected / connect failed;
   - export failed or had nothing to share;
   - rig invalid → sources removed (link to Rig Setup).
3. Keep them brief and non-blocking; nothing that requires a tap while rowing.
4. Pair with task 02 so caught errors have somewhere to go.

## Acceptance criteria

- [ ] Auto-start and auto-stop each produce a visible toast.
- [ ] Connecting and losing a device produces a toast.
- [ ] A failed export explains why instead of doing nothing.
- [ ] No service class takes a `BuildContext` to achieve this.
