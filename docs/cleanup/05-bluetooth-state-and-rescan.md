# 05 — Bluetooth status lies and scanning never restarts

**Priority:** P1 · **Effort:** M · **Area:** bluetooth

## Problem

Three separate defects in `BluetoothManager`, all user-visible:

1. **State never leaves `connected`.** `_onDeviceDisconnected` does not call
   `_updateState`, so the Devices screen reads "connected" forever after every
   device has dropped.
2. **Discovery dies permanently.** `cancelWhenScanComplete` cancels the scan
   results subscription when a scan ends, but `_subscribeToScanResults` is
   guarded by `??=` and is never re-created. Toggling Bluetooth off and on
   leaves the app unable to find any device until it is restarted.
3. **Scanning never stops.** `startScan` has no matching `stopScan` and no
   timeout, so BLE scanning runs for the entire session — a significant battery
   drain on a multi-hour outing.

## Evidence

- `lib/services/bluetooth/bluetooth_manager.dart:141-146` — `_onDeviceDisconnected`
  tears down the stream and removes the device but never updates `_state`.
- `lib/services/bluetooth/bluetooth_manager.dart:67-70` — `??=` guards, then
  `FlutterBluePlus.cancelWhenScanComplete(_scanResultsSubscription!)`.
- `lib/services/bluetooth/bluetooth_manager.dart:201-205` — `_startScanIfReady`
  with no timeout, no `stopScan` anywhere in the file.
- `lib/services/bluetooth/bluetooth_manager.dart:105` —
  `.catchError((_) => _forgetDevice(connection))` silently swallows connect
  failures.

## Fix

1. Derive the reported state from the actual connection set rather than the last
   event: `connected` when `_connectedDevices.isNotEmpty`, otherwise `active`
   (adapter on) / `disabled` / `unsupported`. Call `_updateState` on every
   connect *and* disconnect.
2. Drop `cancelWhenScanComplete`, or re-create the subscription in
   `_startScanIfReady` when it has been cancelled. Verify by toggling the
   adapter.
3. Stop scanning once the expected devices are connected, and rescan on
   disconnect. If continuous discovery is genuinely required, use a periodic
   windowed scan (e.g. 10 s scan every 60 s while something is missing) rather
   than a permanent one.
4. Surface connect/scan failures through the notification mechanism from task
   15 instead of discarding them.

## Acceptance criteria

- [ ] Disconnecting the last device flips the Devices screen back to "active".
- [ ] Toggling the phone's Bluetooth off and on re-discovers and reconnects
      without an app restart.
- [ ] Scanning is not running while all expected devices are connected.
- [ ] A failed connection produces a visible message.
