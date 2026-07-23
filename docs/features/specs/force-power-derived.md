# Spec: Force & power derived sources

**Importance:** Essential · **Complexity:** Medium (per-sample algebra) → Medium-High
(power needs `ω`, per-stroke aggregates need the stroke engine)
**Depends on:** `Force`/`Angle` sources, `Speed`, `BoatConfig` (rig `l_in`,`L`),
`StrokeEngine` (per-stroke aggregates).
**Math:** [`../math/force-power-model.md`](../math/force-power-model.md) — do not restate here.

## Problem

The PO wants handle/blade/oarlock force, instantaneous & per-stroke power, effective vs.
lost force/power, and blade drift/efficiency. All are functions of the measured oarlock
force, angle (+ its derivative), boat speed, and the rig constants. Rig inputs are
**mandatory** ("um mit der Kraftmessung überhaupt was anfangen zu können").

## Per-oarlock instantaneous derived sources

Each is a `DerivedDataSource` (architecture §2.1) built from that oarlock's `Force N` +
`Angle N` (+ boat `Speed` for propulsion/efficiency), with rig constants from
`BoatConfig`. All formulas in force-power-model §1–4.

| Source name | Unit | Formula ref |
|-------------|------|-------------|
| `Oarlock Force N` | N | measured `F_D` (already exists as `Force N`) |
| `Handle Force N` | N | `F_D · l_out/L` (§1) |
| `Blade Force N` | N | `F_D · l_in/L` (§1) |
| `Effective Force N` | N | `F_B · cosθ` (§3) |
| `Lateral Force N` | N | `F_B · sinθ` (§3) |
| `Power N` | W | `F_G · l_in · |ω|` (§2) |
| `Propulsion Power N` | W | `F_B · cosθ · v_boat` (§3) |
| `Blade Slip N` | m/s | `l_out·|ω| − v_boat·cosθ` (§4) |
| `Blade Efficiency N` | % | `v_boat·cosθ / (l_out·|ω|)`, clamped [0,1] then ×100 (§4) |

`ω` = smoothed derivative of angle (detection §1.2); a shared angle→ω transform feeds
`Power`, `Blade Slip`, `Blade Efficiency`.

## Per-stroke aggregate sources (via StrokeEngine cycle boundaries)

One `Measurement` per stroke (force-power-model §6):

| Source name | Unit | Formula ref |
|-------------|------|-------------|
| `Avg Power / Stroke` | W | `(1/T_stroke)∫P dt` (§6) |
| `Peak Power / Stroke` | W | `max P` over cycle (§6) |
| `Avg Drive Force` | N | `(1/T_drive)∫F dt` (§6) |
| `Peak Force / Stroke` | N | `max F` over drive (§6) |
| `Blade Drift / Stroke` | m | `∫ v_slip dt` (§4/§6) |
| `Work / Stroke` | J | `∫P dt` (§6) |

Session peaks of these come **free** from `SessionPeakSource`
([`recording-session.md`](recording-session.md)) — do not re-implement.

## Config dependencies (hard gate)

Force/power sources must not register (or must show "needs rig setup") until
`BoatConfig` provides, per oar: `l_in`, `L` (→ `l_out`). Rig constants are stored **per
physical oarlock device** (the two-oarlock setup is fixed), so they follow the oar across
reconnects. The angle needs no setup — it arrives self-calibrated from firmware
(force-power-model §1, boat-rig-config Part A). See [`boat-rig-config.md`](boat-rig-config.md).

## UI

- All appear in the source picker under group "Force & Power (Oarlock N)"; work with
  existing chart/value tiles and the per-stroke bar chart with no new widget code.
- Effective vs. lateral (or `F(1−cosθ)` loss) — label explicitly which loss definition is
  shown (force-power-model §3).

## Edge cases

- `|ω| → 0` (blade stationary): `Power → 0`; suppress `Blade Efficiency` (undefined),
  clamp slip.
- Missing/zero rig constants → source unavailable with a clear reason, not NaN.
- The propulsion sign relies on the firmware-delivered angle convention (positive toward
  the bow). A one-time firmware/decoder sanity check (force positive during the drive while
  `|θ|` decreases) confirms it; nothing to configure in the app.

## Test notes

- The PO worked example (force-power-model §5) is the golden test:
  `F_D=700, l_in=0.88, L=2.88, ω=2.5, v=4.5, θ=10°` ⇒ `F_G≈486`, `F_B≈214`,
  `P_oar≈1070 W`, `η≈88.6 %`, `P_prop≈948 W`. Assert within tolerance.
- Consistency invariant: `P_prop ≈ η_blade · P_oar` sample-by-sample.
