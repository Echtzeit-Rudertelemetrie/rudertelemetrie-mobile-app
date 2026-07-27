# Math: Force calibration & zero tracking

Status: **spec / math only** — no implementation yet.
Consumes: per-oarlock raw force counts (`uint16`, `MeasurementPack`), 100 Hz.
Produces: calibrated, zero-tracked force in newtons — the `Force N` signal consumed by
[`force-power-model.md`](force-power-model.md) and [`stroke-detection.md`](stroke-detection.md).

The force channel is the one sensor the app must calibrate itself. The angle self-calibrates
in firmware (stroke-detection §1.1); the load cell does not.

---

## 0. Two independent problems

1. **Unknown scale.** The load cell delivers a count proportional to force, with a
   per-sensor constant nobody has measured. The app currently assumes a 1000 N full scale
   (`force_conversion_util.dart`), which is a firmware convention, not a measurement — so
   every force and power number downstream is proportional-but-arbitrary.
2. **Zero drift.** The unloaded reading creeps upward over minutes. A fixed calibration
   fixes the scale but not the offset, and an offset that grows without bound eventually
   dominates the signal and defeats any absolute threshold.

§2 addresses the first, §3 the second, §4 the damage §3 does to stroke detection.

---

## 1. Signal model

For one oarlock, `raw[k] ∈ [0, 65535]` at 100 Hz. Assume the sensor is affine in force
with a slowly varying offset:

```
raw[k] = F[k]/s + r₀ + d(t) + n[k]
```

| term | meaning |
|------|---------|
| `s`    | scale, newtons per count — fixed per sensor |
| `r₀`   | unloaded reading at calibration time |
| `d(t)` | drift; `|d'(t)|` is orders of magnitude below any real force rate |
| `n[k]` | zero-mean noise |

Linearity is assumed over the working range. Two-point calibration cannot detect
curvature; §2.3 bounds the resulting error instead.

---

## 2. Two-point calibration

### 2.1 Capture

Each point is the mean of `N = T_cap · f_s` samples, with the spread recorded:

```
r̄ = (1/N) Σ raw[k]
σ  = sqrt( (1/N) Σ (raw[k] − r̄)² )
```

Reject the point if `σ > σ_max` — a sensor being jostled, or a weight still swinging,
produces a mean that looks fine and is wrong.

### 2.2 Fit

- **Point A**, unloaded → `r₀`
- **Point B**, known mass `m` (kg) applied at the calibration load point → `r₁`

```
F₁ = m · g          g = 9.80665 m/s²
s  = F₁ / (r₁ − r₀)
F(raw) = (raw − r₀) · s
```

Mass is the input, not force: a user can read `5 kg` off a weight but cannot read `49.03 N`
off anything.

### 2.3 Validity and the choice of weight

```
|r₁ − r₀| ≥ Δ_min          (noise-floor guard)
```

`r₁ − r₀` may legitimately be **negative** if the cell is wired inverted; `s` carries the
sign and the reject rule is on magnitude only.

The relative error in `s` is `≈ σ_span / |r₁ − r₀|`, and it multiplies **every** subsequent
reading. Calibrating at 50 N and rowing at 800 N scales the span error 16×. `Δ_min` is a
noise-floor guard, not a substitute for the real requirement:

> choose `m` such that `F₁ ≳ 0.2 · F_peak,expected`.

This is the single most consequential thing the operator controls, and the UI should say so
rather than silently accepting a keyring.

### 2.4 Load point

`F(raw)` is defined as **gate force `F_D`** — precisely the quantity force-power-model §1
converts into handle and blade force via the lever ratios. If the calibration weight hangs
anywhere other than the pin, convert to the pin before fitting. Getting this wrong scales
the entire force *and* power chain by a lever ratio, consistently, and so is invisible in
every internal consistency check.

---

## 3. Live zero tracking

### 3.1 Definition

```
F_out[k] = F(raw[k]) − z[k]
```

`z` tracks the "no rower force" level. It is deliberately **not** `r₀`'s zero: in the boat
the gate carries the static weight of the oar, so the operational zero sits above the
unloaded sensor zero by a constant. Removing that constant is correct — the quantity of
interest is force applied *by the rower*, not the load on the pin. But it means the
calibration zero and the operating zero differ by design, and anything comparing them
must know that.

### 3.2 Estimator

```
ẑ[k] = min{ F(raw[j]) : t[k] − W ≤ t[j] ≤ t[k] }
```

`W` must exceed the longest expected stroke period, so that every window contains at least
one recovery.

Implement as a monotonic deque — O(1) amortised. At 100 Hz over a 5 s window that is 500
samples per oarlock; rescanning per sample would burn ~50 k comparisons/s/oarlock to
recompute a value that changes slowly.

**This estimator needs no stroke boundaries.** "Minimum of the previous stroke" and
"minimum over a trailing window slightly longer than a stroke" are the same statistic to
within one stroke of lag, and the windowed form has no dependency on the detector — which
matters because it would otherwise stop working in exactly the situation where the detector
is already failing.

**Residual under sustained drift.** A trailing minimum of a ramp is the value one window
ago, so a drift of constant rate `ḋ` leaves a standing error

```
z_error ≈ W · ḋ
```

— 5 N at `W = 5 s` and `ḋ = 1 N/s`. This is inherent to the estimator, not to the slew
limiter, and shrinks only by shortening `W`, which `W > T_stroke` bounds from below. It is
accepted: real thermal creep settles rather than ramping indefinitely, and a few newtons of
residual sits far below the catch thresholds it could otherwise disturb. The same bound is
the reason `z_max` (§3.5) is set well above any plausible residual — a runaway flag must
mean a fault, not a brisk warm-up.

### 3.3 Seeding

From a cold start `z = 0` while the true offset may be tens of newtons, and §3.4 would
ramp there slowly. Instead seed `z ← ẑ` once, on the first **quiet** window:

```
max(window) − min(window) < ρ_quiet
```

If no quiet window occurs within `T_seed` — the app connected mid-outing — seed anyway and
let §3.4 correct from there.

### 3.4 Slew limit

```
z[k] = z[k−1] + clamp( ẑ[k] − z[k−1],  −R·Δt,  +R·Δt )
```

`R` sits above the physical drift rate and far below any stroke's rate of change. This one
constraint replaces a phase gate: at `R = 5 N/s` a zero update landing mid-drive is a
5 N/s ramp underneath a 700 N drive — unobservable, and incapable of chasing a real force.
No stroke-boundary synchronisation is required, which is the second reason §3 owes the
detector nothing.

### 3.5 Runaway clamp

```
|z| > z_max  ⇒  needsRecalibration
```

Keep tracking — a stale-but-live zero beats a frozen one — but surface it. Past `z_max` the
sensor has stopped behaving like the thing that was calibrated, and silently absorbing
hundreds of newtons of "drift" would hide a real fault.

---

## 4. Consequences for stroke detection

### 4.1 Why level thresholds alone are unsafe

stroke-detection §5 enters the drive on `F > F_on`. Under upward drift and without §3, `F`
crosses `F_on` with no rower present. §3 removes the steady-state case but not the cold
start: `z` is not yet seeded, and in auto-scaled mode the detector has no `F_peak` yet and
falls back to the absolute `F_on` until a first cycle closes. **The first stroke is always
absolute-gated** — precisely the condition drift defeats.

### 4.2 Rate gate

Drift and a catch are separated by orders of magnitude in `dF/dt`, not in level:

```
drift            ≲     5 N/s
catch    ~600 N in ~150 ms   ≈  4000 N/s
```

So require, in addition to `F > F_on`:

> `dF/dt` exceeded `Ḟ_on` at some point within the last `T_rate`.

computed on a low-pass-filtered `F` — same 1st-order IIR followed by a backward difference
that stroke-detection §1.2 uses for `ω`, at a higher cutoff. At `f_c = 10 Hz`,
`τ = 1/(2πf_c) ≈ 16 ms`, which preserves a 150 ms rise while suppressing sample noise.

The gate is **latched** over `T_rate` rather than evaluated instantaneously, because the
rate peak occurs early on the rising edge and the level crossing slightly after it; they
need not coincide in the same sample.

At `Ḟ_on = 200 N/s` the margin is ~40× above drift and ~20× below a real catch. Unlike a
level threshold, this criterion is **drift-immune by construction** rather than by tuning:
no amount of accumulated offset changes a derivative.

### 4.3 Cold start and idle

Apply the rate gate to every catch, not only the first. It costs one filter per oarlock,
leaves the absolute/auto-scaled distinction untouched, and removes the special case. The
trade-off is a very gentle paddle catch that rises slower than `Ḟ_on`, which is why `Ḟ_on`
is a tunable setting and not a constant.

Separately, `F_peak` must decay or clear after `T_idle`. A peak learned an hour ago should
not be setting the thresholds for the stroke happening now.

---

## 5. Defaults

Starting points, to be tuned against recorded water data — as with stroke-detection §6.

| Symbol | Meaning | Default |
|--------|---------|---------|
| `T_cap`   | capture duration per calibration point | 2.0 s (200 samples) |
| `σ_max`   | capture stability gate | 100 counts |
| `Δ_min`   | minimum usable span | 200 counts |
| `g`       | standard gravity | 9.80665 m/s² |
| `W`       | zero-tracking window | 5.0 s |
| `ρ_quiet` | seed quiet-range threshold | 15 N |
| `T_seed`  | forced-seed timeout | 30 s |
| `R`       | zero slew rate | 5 N/s |
| `z_max`   | runaway clamp | 150 N |
| `f_c`     | force LPF cutoff (for `dF/dt`) | 10 Hz |
| `Ḟ_on`    | catch rate gate | 200 N/s |
| `T_rate`  | rate-gate latch window | 300 ms |

`σ_max` and `Δ_min` are in counts because they apply before any scale is known; everything
after §2.2 is in newtons.
