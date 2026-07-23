# Spec: Boat schematic with live scull angles

**Importance:** Split — showing the **live scull angles** is Essential (PO: "die Winkel
Visualisierungen für Boot und Skulls" are essential); the **schematic-boat-from-above**
form is "sehr nice to have".
**Complexity:** Medium (angle gauges) → High (nice top-view boat graphic)
**Depends on:** `Angle N` sources (self-calibrated in firmware), `BoatConfig` (seat/side
layout for correct placement).

## What

"Ansicht eines schemenhaften Bootes von oben, bei dem man die aktuellen Winkel aller
Skulls eingeblendet bekommt." A top-down boat with each oar drawn at its live angle.

## Two tiers

- **Tier 1 (Essential, ship first):** live angle readout per oarlock — a simple gauge/dial
  per scull showing `θ` (with catch/finish extremes marked). No boat graphic needed; works
  from `Angle N` alone.
- **Tier 2 (Nice-to-have):** a `BoatSchematicTile` (`CustomPaint`) drawing a stylised hull
  from above with each oar as a line pivoting at its pin, rotated by live `θ`, placed on
  the correct side/seat from `BoatConfig` (bow = position 1, Fahrtrichtung up).

## Rendering (Tier 2)

- Subscribe directly to each `Angle N` source (bypass visualizer pipeline, like
  `ValueTile`); use `θ` as delivered (self-calibrated in firmware).
- Draw pins at seat positions; oar line from pin at angle `θ` (0 = perpendicular to hull).
- Optional: colour the oar by instantaneous force (in-water vs. feathered), and shade the
  drive arc.

## Edge cases
- Missing `BoatConfig` layout → fall back to Tier 1 gauges laid out generically.

## Open questions
1. Animate smoothly (interpolate between samples) vs. redraw per sample — smooth for a
   nicer feel; watch battery.
2. Sweep vs. scull rigs change oar count/side rendering — drive from `BoatConfig` class.
