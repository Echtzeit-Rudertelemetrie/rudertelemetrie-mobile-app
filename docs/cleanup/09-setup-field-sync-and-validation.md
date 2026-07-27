# 09 — Setup fields go stale, accept invalid values, and write per keystroke

**Priority:** P1 · **Effort:** M · **Area:** setup screens

## Problem

Three related issues in the rig and stroke-detection setup screens:

1. **Stale fields.** Both number fields build their controller with
   `late final` and never sync it when the incoming value changes. `BoatConfig.load()`
   is async, so if it resolves after the screen is built, the fields show
   defaults while the persisted config is something else — and the first edit
   writes the *displayed* default back over the real value.
2. **No validation.** Nothing enforces `innerLever < scullLength` or
   `fOff < fOn`. Typing `3` into `l_in` with `L = 2.88` makes `outerLever`
   negative, `rig.isValid` false, and `ForceSourceRegistrar` **unregisters every
   force and power source** — dashboard tiles silently go blank with no
   explanation and no route back other than guessing.
3. **Per-keystroke persistence.** `onChanged` fires per character and
   `BoatConfig._persist()` writes the whole JSON file each time. Typing "0.88"
   writes the file four times and tears down and rebuilds the derived source
   graph four times.

## Evidence

- `lib/screens/rig_setup_screen.dart:140-141` and
  `lib/screens/stroke_settings_screen.dart:162-163` — `late final
  TextEditingController`, no `didUpdateWidget`.
- `lib/screens/rig_setup_screen.dart:146-150` — `_handleChanged` only checks
  `parsed > 0`.
- `lib/services/rig/boat_config.dart:97-101,128-132` — `setRig` calls
  `_persist()` synchronously on every change.
- `lib/services/rig/force_source_registrar.dart:44-50` — `!rig.isValid`
  silently removes the built source set.
- `lib/services/rig/boat_config.dart:18` — `isValid` requires
  `outerLever > 0`.

## Fix

1. Add `didUpdateWidget` to both field widgets: when `widget.value` changes and
   differs from the parsed controller text, update the controller (preserving
   cursor position where practical).
2. Validate in the widget and show the reason inline:
   - `l_in` must be `> 0` and `< L`;
   - `L` must be `> l_in`;
   - `F_off` must be `< F_on`.
   Reject the commit and show a red helper text rather than writing an invalid
   config.
3. Debounce the commit (~400 ms after the last keystroke) or commit on focus
   loss / submit. Keep `notifyListeners()` immediate for the displayed value if
   needed, but debounce `store.save`.
4. When a rig is incomplete or invalid, show an explicit banner on the dashboard
   ("Rig incomplete — force and power sources unavailable") instead of tiles
   silently emptying.

## Acceptance criteria

- [ ] Persisted rig values appear in the fields after a cold start, regardless
      of load timing.
- [ ] Entering `l_in > L` shows an inline error and does not unregister sources.
- [ ] Typing a four-character value writes the config file once, not four times.
- [ ] `F_off > F_on` is rejected with a visible reason.
- [ ] Widget tests for stale-value sync and validation rejection (extend
      `test/stroke_settings_screen_test.dart`).
