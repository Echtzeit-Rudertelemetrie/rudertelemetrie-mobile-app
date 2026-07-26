# 18 — Connected Devices screen looks interactive but does nothing

**Priority:** P2 · **Effort:** M · **Area:** bluetooth UI

## Problem

Every device row carries a `chevronRight` — the universal "tap for more" affordance
— but has no `onPress`. Tapping does nothing, which reads as a broken app.

Beyond that the screen offers no control at all: no manual rescan, no
disconnect, no forget, no signal strength, no battery, no indication of which
physical oarlock a row corresponds to. When something is not connecting, the
user's only option is to restart the app (and, per task 05, sometimes that is
genuinely the only thing that works).

## Evidence

- `lib/components/settings/connected_devices/connected_devices_settings.dart:66-70`
  — `FTile` with `suffix: Icon(FIcons.chevronRight)` and no `onPress`.
- Same file, lines 54-73 — the entire UI: a state label and a device list.
- `lib/services/bluetooth/bluetooth_manager.dart` — exposes `state`,
  `connectedDevices` and the two streams; no disconnect/forget/rescan API.
- `lib/services/bluetooth/bluetooth_manager.dart:127` — the row title uses
  `device.advName`, which is the same string for every unit.
- `dispose()` at line 47-51 calls `super.dispose()` **before** cancelling its
  subscriptions (see task 23).

## Fix

1. Either remove the chevron or give the row a detail view. A detail view is the
   better answer: device id, advertised name, connection state, RSSI, which data
   sources it currently provides, and per-device actions.
2. Extend `BluetoothManager` with `disconnect(id)`, `forget(id)` and
   `rescan()`, and expose them in the UI.
3. Show RSSI from the scan result and battery level if the firmware exposes a
   battery characteristic.
4. Let the user label a device ("Bow oarlock") and persist it against the device
   id — this is also what `BoatConfig` keys on, so it makes rig setup far easier
   to reason about than `Oarlock 1 (1A2B)`.
5. Show a clear empty state with a Scan button when nothing is connected.

## Acceptance criteria

- [ ] No control in the screen is inert.
- [ ] The user can trigger a rescan and disconnect/forget a device.
- [ ] Signal strength is visible per device.
- [ ] A user-assigned device label appears in rig and boat setup.
