# 17 — Home screen: nested scaffolds, vague Start, no status at a glance

**Priority:** P2 · **Effort:** S · **Area:** navigation

## Problem

1. **Double `FScaffold`.** `main.dart` wraps `Home` in an `FScaffold`, and
   `Home` returns its own. That is two layers of padding and safe-area inset,
   which is why the home content sits lower and narrower than every other
   screen.
2. **"Start" says nothing.** The primary button opens the dashboard; it does not
   start a recording. Users reasonably expect the opposite from a button labelled
   Start on a telemetry app.
3. **No pre-launch status.** Before carrying the phone to the boat, the user
   cannot see whether the oarlocks are connected, whether the rig is configured,
   or whether GPS is producing fixes. All of that is buried one or two taps deep.
4. **No scrolling.** The content is a plain `Column`; on a small screen with the
   settings list plus the button it can overflow.

## Evidence

- `lib/main.dart:66` — `home: const FScaffold(child: Home())`.
- `lib/screens/home_screen.dart:10` — `Home` returns `FScaffold(...)`.
- `lib/screens/home_screen.dart:18-24` — `FButton(... child: Text("Start"))`
  pushing `DashboardScreen`.
- `lib/screens/home_screen.dart:14-26` — non-scrollable `Column`.

## Fix

1. Remove the outer `FScaffold` from `main.dart` and let each screen own its
   scaffold, matching every other screen in `lib/screens/`.
2. Rename the action to "Open Dashboard" (or make it start a session, if that is
   the intent — pick one and make the label match).
3. Add a compact readiness summary above the settings list:
   - connected oarlocks (count / names),
   - rig configured for each connected oarlock (the gate that silently removes
     force sources, see task 09),
   - GPS fix present,
   - active dashboard preset.
   Each row taps through to the screen that fixes it.
4. Wrap the body in a scroll view.

## Acceptance criteria

- [ ] Home content aligns with the other screens (single scaffold).
- [ ] The primary button's label matches what it does.
- [ ] Connection, rig and GPS readiness are visible without leaving Home.
- [ ] No overflow at 320 dp width with the largest system font scale.
