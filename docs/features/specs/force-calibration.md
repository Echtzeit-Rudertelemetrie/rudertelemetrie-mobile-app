# Spec: Force calibration & zero tracking

**Importance:** Essential (every force and power value is uncalibrated without it) ·
**Complexity:** Medium
**Depends on:** `Force`/`Angle` sources, `BluetoothStreamHandler`, `StrokeEngine` (pause),
`BoatConfig` (oarlock key convention) ·
**Unlocks:** physically meaningful force & power throughout; absolute stroke thresholds
that mean the same thing on every oarlock.
**Math:** [`../math/force-calibration.md`](../math/force-calibration.md), amending
[`../math/stroke-detection.md`](../math/stroke-detection.md) §5.

## Problem

`convertForceSensorData` ([`lib/utils/sensor_data/force_conversion_util.dart`](../../../lib/utils/sensor_data/force_conversion_util.dart))
maps the raw `uint16` onto a 0–1000 N range on a firmware convention, not a measurement.
The number is proportional to force and otherwise arbitrary, so `Handle Force`,
`Blade Force`, `Power`, and the absolute stroke thresholds are all in arbitrary units
wearing a newton label.

Separately, the unloaded reading drifts upward over minutes. Fixing the scale does not fix
that, and a growing offset eventually walks the signal across any absolute threshold with
nobody in the boat.

## Decisions taken up front

**1. One `Force N` source per oarlock, always calibrated. No raw source is registered.**

An uncalibrated source looked necessary in three places and is needed in none:

- *The calibration flow* genuinely needs the uncalibrated reading, but as a **tap** into
  `ForceCalibrationSession`, not a registered source. The operator never sees a raw count —
  step 1 is "don't touch it", step 2 is "hang the weight, enter its mass".
- *Recording*, so a bad calibration doesn't ruin a session. Redundant: the transform is
  affine, so `raw = F/s + r₀` inverts exactly. Persisting the constants (§Persistence)
  gives everything a raw series would, at a few bytes instead of a second 100 Hz stream per
  oarlock. The live zero is time-varying, but bounded to 5 N/s, so logging `z` at 1 Hz
  keeps the whole chain invertible.
- *The uncalibrated fallback* is a **default calibration** — same source, different
  constants — not a second source.

Registering both would also put two `Force` entries per oarlock in the widget picker, and
"which Force do I chart?" is a bad question to hand someone mid-outing.

**2. Calibration is applied at ingest**, in `_OarlockStream`, where `convertForceSensorData`
sits today. It is the single point where a raw count becomes a physical quantity. The
alternative — a derived source layered on a renamed raw `Force N` — would ripple through
`StrokeEngine`, `ForceSourceRegistrar`, `PowerSourceRegistrar` and their tests, *and* break
every saved dashboard and preset, which persist bindings by source name (`sourceKeys`,
[`stream_selector_sheet.dart:35`](../../../lib/dashboard/stream_selector_sheet.dart)).

**3. Zero tracking does not depend on stroke detection.** A trailing-window minimum
(math §3.2) is the same statistic as "minimum of the previous stroke" without the feedback
loop `ingest → detector → zero → ingest`, and without failing exactly when the detector is
already failing.

## Components

New, under `lib/services/calibration/` — a sensor-level concern, distinct from
`lib/services/rig/`, which is geometry:

| File | Responsibility |
|------|----------------|
| `force_calibration.dart` | `ForceCalibration` value object: `{zeroRaw, spanRaw, spanNewtons, calibratedAt}`, `double newtons(int raw)`, `ForceCalibration.fit(...)` with the math §2.3 validity rules, `toJson`/`fromJson`. Pure. |
| `zero_tracker.dart` | Monotonic-deque rolling minimum + seed + slew + runaway clamp (math §3). Pure, time-driven by the sample timestamps. |
| `force_calibrations.dart` | `ChangeNotifier` keyed by oarlock key. Owns the persisted `ForceCalibration` **and** the ephemeral `ZeroTracker` per oarlock. Exposes `double newtons(String key, int raw, DateTime t)`, `offsetFor(key)`, `needsRecalibration(key)`, and the raw tap. |
| `force_calibration_store.dart` | File-backed `force_calibration.json`, mirroring `FileBoatConfigStore` including corrupt-file quarantine. |
| `force_calibration_session.dart` | The calibration state machine (§Calibration mode). |

Also new:

| File | Responsibility |
|------|----------------|
| `lib/services/stroke/low_pass_differentiator.dart` | IIR low-pass + backward difference (math §4.2), extracted from `AngleDifferentiator`, which now wraps it. Angle and force differ only in cutoff and reported units, so the force side needs no class of its own. |
| `lib/providers/force_calibration_provider.dart` | `forceCalibrationsProvider` + `forceCalibrationSessionProvider`, following `boatConfigProvider`. |
| `lib/screens/force_calibration_setup_screen.dart` | Per-oarlock status list: calibrated or provisional, live drift, entry to the flow. |
| `lib/screens/force_calibration_screen.dart` | The guided flow. |

Modified:

| File | Change |
|------|--------|
| `utils/sensor_data/force_conversion_util.dart` | Stops assigning physical meaning. Keeps only the default-calibration constants used when an oarlock has never been calibrated. |
| `services/bluetooth/bluetooth_stream_handler.dart` | `_OarlockStream` takes the oarlock key and `ForceCalibrations`; line 221 becomes `calibrations.newtons(key, packet.forces[i], timestamp)`. |
| `services/bluetooth/bluetooth_manager.dart` | `initialize(registry, calibrations)`; pass through at the construction site (line 258). |
| `providers/bluetooth_provider.dart`, `utils/startup_util.dart` | Wiring for the above. |
| `services/stroke/oarlock_stroke_detector.dart` | Rate gate on the catch; `F_peak` decay after `T_idle`. |
| `services/stroke/stroke_settings.dart` | `Ḟ_on`, `T_rate`, `f_c` as tunables. |
| `services/stroke/stroke_engine.dart` | `pause()`/`resume()` (§Calibration mode). |
| `components/settings_section.dart` | "Force Calibration" entry in Settings. |
| `screens/history_screen.dart` | "uncalibrated" badge on provisional sessions. |
| `services/recording/recording_session.dart` | Takes `ForceCalibrations`; snapshots the constants on stop and samples the zero trace on its existing 1 Hz ticker. |
| `services/recording/session_record.dart` | Calibration constants + zero trace (§Persistence). |

## Pipeline placement

```
raw uint16 ──► ForceCalibrations.newtons(key, raw, t)
                 │   F = (raw − r₀)·s          [ForceCalibration]
                 └─► F_out = F − z(t)          [ZeroTracker]
                       │
                       └─► PushDataSource "Force N"  ──► everything downstream, unchanged
```

Nothing after the arrow changes. `StrokeEngine`, `ForceSourceRegistrar` and
`PowerSourceRegistrar` keep matching `^Force \d` and keep receiving newtons — real ones.

## Calibration mode

`ForceCalibrationSession` (`ChangeNotifier`) drives one oarlock at a time:

```
idle → capturingZero → awaitingWeight → capturingSpan → review → (commit | discard)
```

- Each capture averages `T_cap` of samples from the raw tap and computes σ; `σ > σ_max`
  fails the step with "hold still and retry" rather than committing a bad point.
- `awaitingWeight` collects the mass in **kg**.
- `review` shows the fitted scale, the implied full-scale force, and — when
  `F₁ < 0.2 · F_peak,expected` — an explicit extrapolation warning (math §2.3).
- `commit` writes through `ForceCalibrations` and resets that oarlock's `ZeroTracker`,
  since its reference has moved.

**While a session is active** (any oarlock):

- `StrokeEngine.pause()` — stop feeding detectors, clear `_pending`, cancel `_quorumTimer`.
  Pausing a single detector instead would leave crew aggregation waiting on it until the
  quorum window fired a phantom stroke.
- All `ZeroTracker`s pause. Hanging a weight is not drift.
- Recording auto-start is suppressed for free: it is driven by `onRowingDetected` from
  `_onEvent`, and a paused engine emits no events.
- Entering calibration is **blocked while a recording is active**. Calibrating mid-session
  would silently change the meaning of the data already in it.

On `resume()`: `detector.reset()` for every oarlock — the method exists at
[`oarlock_stroke_detector.dart:134`](../../../lib/services/stroke/oarlock_stroke_detector.dart)
and is currently called from nowhere — and clear `_previousFinish`, so the first
post-calibration stroke does not compute its period against a finish from before the break.

## Detector changes

Per math §4.2–4.3, in `OarlockStrokeDetector`:

1. Feed each sample through a `ForceDifferentiator`.
2. Latch `_rateGateUntil = t + T_rate` whenever `dF/dt > Ḟ_on`.
3. The catch requires `force > _fOn` **and** `t ≤ _rateGateUntil`.
4. Clear `_recentPeakForce` when the gap since the last finish exceeds `T_idle`.

Steps 1–3 are ~10 lines and leave the absolute/auto-scaled structure intact.

## Persistence

`force_calibration.json`, keyed by oarlock key (the source group, e.g.
`Oarlock 1 (1A2B)`) — the same convention `BoatConfig` uses, so calibration follows the
physical oarlock across reconnects. Separate file from `boat_config.json`: recalibrating
should not rewrite rig geometry.

Session records gain, per oarlock:

- the `ForceCalibration` constants in force at recording time,
- a 1 Hz `z(t)` trace.

Together these make the recorded newtons losslessly re-interpretable if a calibration is
later found to be wrong. Sessions recorded under a default calibration carry
`calibratedAt: null` and are marked provisional in the history screen.

## UI

- **Entry point:** a "Force Calibration" item in Settings, opening a per-oarlock list, rather
  than the connected-devices screen this spec first proposed — that screen lists *devices*,
  and calibration is per *oarlock*. The list mirrors `RigSetupScreen`, which already solves
  exactly this "one card per oarlock key" problem.
- **Badges:** "uncalibrated" for `calibratedAt == null`, "recalibrate" when
  `needsRecalibration` (math §3.5) or when the calibration is older than a configurable age.
- **The flow itself** is three screens of one instruction each. Show a stability indicator
  during capture, never a raw count — a raw count invites the operator to interpret it.
- **Live drift readout** in the calibration entry screen (`offsetFor(key)`), so a rower can
  see whether the sensor is behaving.

## Migration

- An oarlock with no stored calibration gets `ForceCalibration.defaultFor(...)` — the
  current 1000 N-full-scale mapping, with `calibratedAt: null`. Nothing breaks; the app is
  as correct as it is today, and now says so.
- `F_on = 40` / `F_off = 20` ([`stroke_settings.dart:16`](../../../lib/services/stroke/stroke_settings.dart))
  were chosen against the fake scale. They need re-tuning against real water data once
  calibration lands. The upside: after calibration these are finally comparable *across*
  oarlocks, which they are not today.
- `docs/features/README.md` "Hardware & firmware constants" claims force is "0–1000 N full
  scale". Correct it to describe the raw encoding and point here.

## Edge cases

- **Inverted cell** (`r₁ < r₀`): permitted, `s` carries the sign; only `|r₁ − r₀| ≥ Δ_min`
  is enforced.
- **Weight too light:** `Δ_min` rejects the degenerate case; the extrapolation warning
  covers the merely-unwise case.
- **Disconnect mid-calibration:** abort to `idle`, commit nothing, resume the engine.
- **Disconnect mid-session:** `ZeroTracker` state is ephemeral and resets; the calibration
  persists. A reconnected oarlock re-seeds from its first quiet window.
- **App connects mid-outing:** no quiet window arrives, so `T_seed` forces a seed and the
  slew limiter corrects from there.
- **Oarlock forgotten:** `forgetOarlock` (`services/rig/oarlocks.dart`) drops rig, seat and
  calibration together. Two stores with independent lifetimes make "remove this oarlock" one
  intent spanning both, and it has to be named in one place or the half nobody remembered
  outlives the device — a stale calibration would then be silently reapplied to whatever
  oarlock next claimed that key.
- **Cancelling a capture subscription:** not awaited. `StreamSubscription.cancel()` on a
  broadcast stream can return a future that never completes, which would strand the state
  machine mid-capture; the samples are already in hand by then.
- **Screen disposed without a pop** (a route replaced from elsewhere): `PopScope` never
  fires, so `dispose()` is a second, deferred cancel. Without it, zero tracking would stay
  paused for the rest of the outing with nothing on screen saying so.

## Tests

New:

- `test/force_calibration_test.dart` — fit correctness; `newtons` round-trips
  `raw → F → raw`; `Δ_min` rejection; inverted-cell sign; default calibration matches
  today's `convertForceSensorData` exactly (a regression guard on the migration).
- `test/zero_tracker_test.dart` — rolling min over a synthetic stroke train; seeding only
  on a quiet window; `T_seed` forced seed; slew limit holds under a step input; `z_max`
  raises `needsRecalibration`.
- `test/force_calibration_store_test.dart` — round-trip + corrupt-file quarantine, mirroring
  `boat_config_store_test.dart`.
- `test/force_calibration_session_test.dart` — state machine; σ rejection; tracking paused for
  the duration. Runs on a `FakeAsync` clock, so the two-second captures cost no wall time.
- `test/session_force_provenance_test.dart` — provisional marking; JSON round-trip of the
  constants and zero trace; a pre-calibration session still loading; and the invertibility
  claim above, asserted end-to-end.

Updated:

- `test/stroke_detection_test.dart` — **a linear drift ramp across `F_on` must produce no
  stroke**; a synthetic catch still must. This is the test that encodes the whole point.
- `test/sensor_conversion_test.dart` — force cases move to the calibration tests.
- `test/bluetooth_stream_handler_test.dart` — calibration applied at ingest.
- `test/stroke_engine_test.dart` — pause clears pending cycles and cancels the quorum timer.

## Open

- **`F_peak,expected` is a guess.** `ForceCalibrationSession.assumedPeakNewtons = 800` drives
  the "that weight is too light" warning and has no field data behind it. Replace it with a
  measured figure and the warning becomes a concrete "use at least X kg".
- **`F_on = 40` / `F_off = 20` still carry over from the nominal scale** and want re-tuning
  against calibrated water data, as does `Ḟ_on = 200 N/s`.
- **`σ_max = 100` counts** is a placeholder; a real cell's noise floor should set it.

## Phasing

Each phase is independently shippable and leaves the app working.

1. **Calibration core.** `ForceCalibration`, store, `ForceCalibrations` with the zero
   tracker *disabled*; wire into ingest with the default calibration. No user-visible
   change, no behaviour change — pure plumbing, fully unit-tested.
2. **Calibration mode + UI.** Session state machine, engine pause, the screens. End of this
   phase the numbers are real.
3. **Zero tracking on.** Enable `ZeroTracker`, add the drift readout and the
   `needsRecalibration` badge.
4. **Detector hardening.** Rate gate, `F_peak` idle decay, new settings, drift-ramp test.
5. **Session metadata.** Calibration constants + `z` trace into `SessionRecord`; provisional
   marking in history; README constants corrected.

Phases 3 and 4 are separable but should ship together in one field-test cycle — 3 changes
what the detector sees, and 4 is what makes that safe.
