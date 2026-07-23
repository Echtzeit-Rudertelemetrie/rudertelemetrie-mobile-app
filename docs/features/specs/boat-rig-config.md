# Spec: Boat & rig configuration (setup)

**Importance:** Mixed — the **rig inputs** (`l_in`, `L`) are Essential (force/power is
useless without them); the **boat/seat setup with graphics** is explicitly deprioritised
by the PO ("kannst dich erstmal mehr auf die anderen Features konzentrieren").
**Complexity:** Low (rig number fields) → High (full boat picker + graphic + rigging).
**Depends on:** nothing · **Unlocks:** all force/power sources, boat schematic, stroke
crew-aggregation.

Split into two independently shippable parts.

## Part A — Rig inputs (Essential, do first)

Minimal `BoatConfig` (ChangeNotifier, persisted like the dashboard layout) holding one
entry **per physical oarlock device** (keyed by device id, so config survives reconnects;
one `l_in`/`L` per instrumented oarlock, sculling or sweep):

| Field | Unit | Used by |
|-------|------|---------|
| `innerLever l_in` | m | force-power model (mandatory) |
| `scullLength L` | m | force-power model (mandatory); `l_out = L − l_in` |

### The angle needs no app configuration

The angle arrives **self-calibrated from firmware**: it is a fixed **±180°** signed value
(`DataSender.h`: `angle_deg = code/65535·360 − 180`, matched by the app decoder), produced
by the per-oarlock ICM-20948 orientation EKF, which **zeroes and calibrates itself in
firmware**. The app therefore stores **no** angle offset/sign and performs **no** angle
calibration — it consumes `θ` as delivered (zero at the perpendicular, positive toward the
bow) and any zero/drift correction is the firmware's job.

> Minor app cleanup (not a config concern): fix the stale `−90…+90°` comment in
> `angle_conversion_util.dart` — the ±180° decode itself is correct.

**Other fixed firmware constants** (no app config needed): the per-oarlock **sample rate is
100 Hz** (ForceReader/AngleReader), and **GPS speed** is integer-truncated m/s so the app
derives speed from position instead (kinematics §1) — no speed-scaling constant to configure.

### UI (Part A)
A "Setup → Rig" settings section (reuse `settings_section.dart`): numeric fields per
connected oarlock for `l_in`, `L`. Defaults from the PO example (`L=2.88, l_in=0.88`) as
placeholders. No angle-calibration step.

## Part B — Boat & crew layout (Nice-to-have, deprioritised)

`BoatConfig` extends with:

- **Boat class** (1x, 2x, 2-, 4x, …) → number of seats.
- **Seat numbering**: position **1 = bow** (Fahrtrichtung), counting sternward — per the
  PO ("auf Position 1 sitzt die Person ganz im Bug").
- Per seat: **side** (Steuerbord/Backbord for sweep; both for sculling) and the **oarlock
  device** bound to it.
- Optional boat **graphic** for the picker/assignment (nice-to-have within a
  nice-to-have).

### UI (Part B)
A setup wizard: pick boat class → assign each connected oarlock device to a seat/side →
confirm. Feeds the boat schematic ([`widget-boat-schematic.md`](widget-boat-schematic.md))
and crew aggregation (which oarlock is "bow" reference). With only two oarlocks in the
current hardware this can stay a simple list; the graphic is the last thing to add.

## Edge cases
- Fewer connected devices than seats → leave seats unassigned; metrics degrade gracefully.
- Oarlock reassigned to another seat → rig constants **follow the physical oarlock device**
  (they are stored per device id), not the seat.
