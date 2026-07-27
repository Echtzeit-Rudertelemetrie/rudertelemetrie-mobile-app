# 06 — Oarlock timestamps are not anchored to a device clock origin

**Priority:** P1 · **Effort:** S · **Area:** bluetooth / data pipeline

## Problem

The boat packet path anchors the firmware clock to the first value it sees. The
oarlock path does not — it feeds the raw firmware `sequenceNumber` straight into
`startTime + sequenceIndex × 5 ms`.

If the boat has been powered on for a while before the phone connects, the
sequence number is already large and **every oarlock sample is timestamped far
in the future**. Ten minutes of uptime puts samples hours ahead of `now`.

Consequences: chart time axes blow up, `elapsed_ms` in the session CSV is
meaningless, and `CombineLatestSource`'s 5 ms alignment between oarlock sources
and the boat's `Speed` can never match — so `Propulsion Power`, `Blade Slip` and
`Blade Efficiency` produce nothing at all.

## Evidence

- `lib/services/bluetooth/bluetooth_stream_handler.dart:83-86` — the boat path,
  correct: `final origin = _boatDeviceClockOrigin ??= deviceMs;`
- `lib/services/bluetooth/bluetooth_stream_handler.dart:88-94` — the oarlock
  path, unanchored: passes `packetSequenceNumber` through unchanged.
- `lib/utils/bluetooth/timestamp_conversion_util.dart:11-19` —
  `sampleIndex = packetSequenceNumber * 32 + index`, multiplied by 5 ms.
- `lib/services/rig/force_sources.dart:104-132` — the speed-dependent sources
  rely on timestamp alignment with `tolerance: 5ms`.

## Fix

Mirror the boat approach: record the first sequence number seen per oarlock and
offset from it.

```dart
final Map<String, int> _oarlockSequenceOrigin = {};

DateTime _timestampFor(PushDataSource source, String key, int seq, int index) {
  final origin = _oarlockSequenceOrigin[key] ??= seq;
  return convertSequenceNumbersToTimestamp(source.startTime, seq - origin, index);
}
```

Consider also handling sequence wraparound (the field is 29 bits) and a
reconnect resetting the origin while `startTime` also resets — the two must be
re-anchored together.

## Acceptance criteria

- [ ] Connecting to a device whose sequence counter is already at, say,
      1,000,000 produces sample timestamps within a few seconds of `now`.
- [ ] `Propulsion Power` / `Blade Slip` / `Blade Efficiency` emit values when
      both an oarlock and boat GPS speed are present.
- [ ] Session CSV `elapsed_ms` values start near 0.
- [ ] Unit test in `test/sensor_conversion_test.dart` or a new
      `bluetooth_stream_handler_test.dart` covering a large starting sequence.
