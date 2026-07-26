# 10 — Boat setup overflows for an eight and allows contradictory assignments

**Priority:** P1 · **Effort:** S · **Area:** setup screens

## Problem

The seat selector puts a label plus one chip per seat in a bare `Row`. For
`BoatClass.eight` that is 8 chips plus a label on one line — a guaranteed
`RenderFlex overflowed` error on any phone.

Beyond the overflow, the screen permits states the boat cannot physically be in:
two oarlocks can be assigned the same seat *and* side, and there is no way to
unassign an oarlock or remove config for a device that will never return.

## Evidence

- `lib/screens/boat_setup_screen.dart:96-110` — `Row` with
  `for (var s = 1; s <= seats; s++)` and no wrapping or scrolling.
- `lib/services/rig/boat_config.dart:37` — `eight('8+', 8, false)`.
- `lib/services/rig/boat_config.dart:116-120` — `assignSlot` overwrites with no
  conflict check.
- `lib/services/rig/boat_config.dart:122-126` — `clearSlot` exists but no UI
  calls it.
- The boat class selector at `boat_setup_screen.dart:35-46` already uses `Wrap`
  correctly — apply the same treatment.

## Fix

1. Replace the seat `Row` with `Wrap` (matching the boat-class selector) or a
   horizontally scrollable row.
2. Detect duplicate seat+side assignments and mark them — either block the
   selection or show a warning chip. `computeBoatLayout` currently trusts the
   slots and will draw two oars on top of each other.
3. Add an "unassign" action per oarlock, wired to the existing `clearSlot`, and
   a way to remove stale oarlock entries entirely (also calling `removeRig`) so
   config does not accumulate for every device ever seen.

## Acceptance criteria

- [ ] Selecting boat class `8+` renders without an overflow error on a 360 dp
      wide screen.
- [ ] Assigning two oarlocks the same seat and side is prevented or clearly
      flagged.
- [ ] An oarlock can be unassigned, and a stale one removed from config.
- [ ] Widget test rendering `BoatSetupScreen` at `8+` asserting no overflow.
