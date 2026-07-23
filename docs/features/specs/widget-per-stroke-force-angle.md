# Spec: Per-stroke force / angle curve

**Importance:** Essential-ish (PO: "das pro Schlag Diagramm, das wir schon besprochen
hatten") · **Complexity:** Low (enhancement of an existing feature)
**Depends on:** `StrokeEngine` (clean triggers) · **Refs:** existing `X vs Y (Stroke)`
visualizer + `SinceThresholdCollector`.

## What

The force-vs-angle (or force/angle-vs-time) curve for the current stroke — the classic
rowing "force curve". **A rough version already exists**: `X vs Y (Stroke)` binds two
sources with `SmoothedXyCollector(SinceThresholdCollector)`, i.e. force (y) vs angle (x)
collected since a force threshold crossing. This spec upgrades it.

## Enhancements over today

1. **Trigger from real stroke events** (catch→finish from `StrokeEngine`) instead of a raw
   force threshold, so the curve is segmented on true drive boundaries and matches the
   other per-stroke metrics.
2. **Overlay / ghost curves**: draw the previous stroke (and/or a session-average curve)
   faintly behind the current one for shape comparison.
3. Selectable axes: `Force vs Angle` (curve shape) **or** `Force vs Time` / `Angle vs
   Time` within the drive.
4. Optional per-oarlock overlay so a crew sees both blades' curves together.

## Pipeline

- Replace the threshold trigger with a `StrokeGatedCollector` driven by the stroke-event
  stream (drive interval = [catch, finish]). Keep `SmoothedXyCollector` for the XY case.
- Average curve = resample each drive onto a **normalised angle axis** (catch→finish sweep
  mapped to [0,1]) and mean the last N drives. Angle-normalisation (not time) keeps strokes
  physically comparable regardless of rate.

## Edge cases
- No stroke engine yet → keep the current threshold behaviour as a fallback.
- Very short/aborted drives → skip from the overlay average.
