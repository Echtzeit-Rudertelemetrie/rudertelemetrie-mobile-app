# Math: Force & power model

Status: **spec / math only** — no implementation yet.
Consumes: per-oarlock `Force N` (measured oarlock force, N), `Angle N` (deg) and its
derivative `ω` (rad/s, see [stroke-detection §1.2](stroke-detection.md)), boat `Speed`
(m/s); plus the rig constants `l_in`, `L` from
[`../specs/boat-rig-config.md`](../specs/boat-rig-config.md).
Produces: the derived data sources in
[`../specs/force-power-derived.md`](../specs/force-power-derived.md).

This formalises the physics the PO supplied. Every quantity here is an instantaneous
function of the samples (plus per-stroke integrals defined in §6), so each becomes a
derived stream evaluated sample-by-sample.

---

## 1. Rig geometry and the three forces

The scull is a lever pivoting at the **oarlock pin**. Let

- `l_in`  = inner lever, pin → handle (m),
- `l_out` = outer lever, pin → blade pressure point (m),
- `L = l_in + l_out` = effective scull length (m).

> `l_out` is the pin→**pressure-point** distance, **not** the physical blade tip. The
> pressure point sits somewhat inside the blade centre and wanders during the drive;
> we approximate it as a constant `l_out = L − l_in` and flag the systematic error in §7.

All three forces are the components **perpendicular to the shaft**. Moment balance about
the pin (`F_G · l_in = F_B · l_out`) gives:

```
Measured: F_D                         # oarlock (pin reaction) force, perpendicular to shaft
Handle:   F_G = F_D · l_out / L       # what the rower pulls   (< F_D)
Blade:    F_B = F_D · l_in  / L       # water reaction on blade (< F_D)
Identity: F_D = F_G + F_B             # the two add up at the pin
Ratio:    F_B = F_G · l_in / l_out
```

**Which force does our sensor report? — Confirmed perpendicular.** The load cell sits on
the oarlock where the scull presses against the iron pin, so it reads the pin reaction
**perpendicular to the shaft** (`F_D`). These formulas therefore apply directly:
`P = F·l·ω` and `F_prop = F·cos θ` (§3), with no double-`cos θ`. The firmware quantises it
0–1000 N full scale (`DataSender.h`, `ForceReader` at 100 Hz), matching the app decoder.

The alternate `longitudinal` case (a sensor reading pin bending along the boat axis, which
would already be `F_D · cos θ`) is **not** our hardware; it is kept only as a config flag
`force_sensor_axis ∈ {perpendicular, longitudinal}` (default `perpendicular`) in
boat-rig-config so the math stays reusable if a different rig is ever instrumented. §3 below
uses `perpendicular`.

---

## 2. Instantaneous power at the oar

Power = torque × angular velocity = perpendicular handle force × handle speed:

```
v_handle = l_in · |ω|
P_oar(t) = F_G(t) · l_in · |ω(t)|  =  F_G(t) · v_handle
         = F_D(t) · (l_out / L) · l_in · |ω(t)|
```

**`cos θ` does not appear here.** The angle governs how much of this work becomes
propulsion (§3), not the work done at the handle. `P_oar` is the mechanical power fed
into the oar in the boat reference frame — close to, but not identical with, the
athlete's total power (§7).

`ω` is obtained by smoothed differentiation of `θ` (stroke-detection §1.2). Because
`P_oar ∝ |ω|`, angle noise is the dominant error source — the LPF cutoff choice directly
sets power-signal quality.

---

## 3. Propulsion: effective vs. lost components

Only the component along the boat's travel direction propels. With `θ` measured from the
perpendicular-to-boat (stroke-detection §1.1):

```
propulsive fraction         = cos θ
Effective (propulsive) force:  F_prop  = F_B · cos θ        # blade force driving the system
Lateral (wasted) force:        F_lat   = F_B · sin θ        # sideways, does no forward work
Angle-loss magnitude:          F_loss  = F_B · (1 − cos θ)  # shortfall of |F| vs its forward part
```

- Use **`F_lat = F·sin θ`** as the physically meaningful "force that does not contribute
  to propulsion" (the orthogonal component). `F_loss = F(1−cos θ)` is the scalar
  shortfall and is offered as an alternative readout; be explicit in the UI which one is
  shown. At `θ = 60°` (catch) `cos θ = 0.5`, so half the force is off-axis.
- The same projection applies to the handle/oarlock force if the user wants
  "effective handle force" — but propulsion of the boat+rower system is driven by the
  **blade** force, so `F_prop` uses `F_B`.

**Propulsion power** (blade power actually delivered to forward motion):

```
P_prop(t) = F_B(t) · cos θ(t) · v_boat(t)
```

---

## 4. Blade efficiency and slip ("Drift des Blattes")

The blade's speed relative to the boat, perpendicular to the shaft, is `l_out · |ω|`.
The boat's own motion contributes `v_boat · cos θ` in that direction, so the blade
**slips** through the water at:

```
v_slip(t) = l_out · |ω(t)| − v_boat(t) · cos θ(t)     # blade drift speed through water (m/s)
```

Blade (propulsive) efficiency:

```
η_blade(t) = 1 − v_slip / (l_out · |ω|)  =  v_boat · cos θ / (l_out · |ω|)
```

`η_blade = 1` when the blade is anchored (no slip). It is highest mid-drive (`cos θ ≈ 1`,
small slip) and lowest at catch/finish. The two power routes are **identical**, which is
the internal consistency check:

```
P_prop  =  η_blade · P_oar      (should hold sample-by-sample up to numerical error)
Water loss:  P_slip = P_oar − P_prop = (1 − η_blade) · P_oar
```

**Blade drift distance** per drive (the PO's "Drift des Blattes im Wasser" as a length):

```
s_slip[n] = ∫_{D[n]} v_slip(t) dt        # metres the blade travels through the water per stroke
```

Edge case: near catch/finish `l_out·|ω|` can approach `v_boat·cos θ` or zero; clamp
`η_blade ∈ [0, 1]` and suppress it when `|ω|` is below a small floor (blade not moving).

---

## 5. Worked example (PO's numbers, reproduced as a test vector)

Rig `L = 2.88`, `l_in = 0.88`, `l_out = 2.00` m; measured `F_D = 700 N`.

```
F_G = 700 · 2.00/2.88 = 486.1 N
F_B = 700 − 486.1      = 213.9 N
ω = 2.5 rad/s:  P_oar = 486.1 · 0.88 · 2.5 ≈ 1070 W
θ = 10°, v_boat = 4.5 m/s:
  blade speed rel. boat = 2.00 · 2.5 = 5.00 m/s
  v_boat·cos θ = 4.43 m/s  ⇒  v_slip = 0.57 m/s
  η_blade = 4.43 / 5.00 = 88.6 %
  P_prop  = 213.9 · 4.43 = 948 W ;  water loss = 122 W ;  sum = 1070 W ✓
```

These exact figures should become a unit test for the derived-source math.

---

## 6. Per-stroke aggregates (attached to the stroke-detection cycle `n`)

For each closed cycle `n` (drive `D[n]`, period `T_stroke[n]`):

```
P_avg_stroke[n]  = (1/T_stroke[n]) · ∫_{cycle n} P_oar dt     # average power per stroke
P_avg_drive[n]   = (1/T_drive[n])  · ∫_{D[n]}   P_oar dt     # drive-only average (alt.)
P_peak_stroke[n] = max_{t ∈ cycle n} P_oar(t)                # peak power per stroke
W_stroke[n]      = ∫_{cycle n} P_oar dt                      # work per stroke (J)
F_peak_stroke[n] = max_{t ∈ D[n]} F_D(t)                     # peak oarlock force per stroke
F_avg_drive[n]   = (1/T_drive[n]) · ∫_{D[n]} F_D dt          # average drive force
s_slip[n]        = ∫_{D[n]} v_slip dt                        # blade drift per stroke (§4)
```

`P_avg_stroke` (over the **whole** cycle) is the PO's "Durchschnittsleistung pro Schlag";
`P_avg_drive` is offered alongside because drive-average is what many rowing systems show.
Integrals use the trapezoidal rule over the irregular sample timestamps.

### 6.1 Peak-since-session

The PO wants **every** per-stroke value also as a session peak. This is a generic
running max over the per-stroke stream, owned by the recording session
([`../specs/recording-session.md`](../specs/recording-session.md)), not re-derived here:

```
Peak_X_session = max over all strokes n since recording start of X[n]
```

Applies to `P_peak_stroke`, `F_peak_stroke`, `SPM`, boat speed, etc.

---

## 7. Modelling limits (carry into the UI as caveats, not silent assumptions)

1. `P_oar` is oar power in the boat frame. Athlete total power is ~10–20 % higher (moving
   own body mass against the boat) and metabolic power far higher (muscle efficiency
   ~20–25 %). Do not label `P_oar` as "the rower's power" without qualification.
2. Real blades develop lift, especially at the catch — the perpendicular-force assumption
   (§1) is an approximation; the axial component then does some work we ignore.
3. `l_out` to the pressure point is not the scull length and drifts during the stroke,
   biasing `η_blade` systematically.
4. `v_boat` from GPS is speed over ground; for `η_blade` the speed **relative to the
   water** matters. Wind/current bias it. Note it; don't correct it without a water-speed
   source.
5. If `force_sensor_axis = longitudinal`, `F_prop = F_measured · v_boat` directly (no
   extra `cos θ`), and `F_D = F_measured / cos θ` to recover the perpendicular force.

## 8. Required inputs summary

| Input                | Source | Notes |
|----------------------|--------|-------|
| `F_D(t)`             | `Force N` stream | perpendicular-to-shaft, 0–1000 N (confirmed §1) |
| `θ(t)`, `ω(t)`       | `Angle N` stream + §1.2 | ±180° range; self-calibrated in firmware, consumed as-is |
| `v_boat(t)`          | `Speed`/position | GPS over-ground; prefer position-derived (kinematics §1) |
| `l_in`, `L`          | rig config | **mandatory**; `l_out = L − l_in` |
| `force_sensor_axis`  | rig config | perpendicular (our hardware) \| longitudinal |
| cycle boundaries `D[n]`, `T_stroke[n]` | stroke engine | for §6 aggregates |
