# Cleanup backlog

Actionable task specs from the full-app review (July 2026, branch `phase5`).
Each file is one self-contained task: problem, evidence, fix, acceptance criteria.

Two findings from that review are already fixed and are **not** in this backlog:

- Angle conversion (`±180` scale) — code, comment and tests now agree.
- Dashboard layout not persisted — replaced by the named-preset system
  (`lib/dashboard/dashboard_preset*.dart`, `preset_sheet.dart`).

## Priority 0 — correctness, do first

| # | Task | Impact |
|---|------|--------|
| [01](01-session-stop-reset-race.md) | Stop→Reset race deletes the saved session | Silent data loss |
| [02](02-error-handling-and-recovery.md) | No error handling anywhere in `lib/` | Corrupt file = unusable screen |

## Priority 1 — bugs users will hit

| # | Task | Impact |
|---|------|--------|
| [03](03-instrument-tile-rebinding.md) | Level/Map tiles never rebind to late sources | Tile dead forever |
| [04](04-visualizer-cache-invalidation.md) | Charts wiped on every dashboard interaction | Loses live history |
| [05](05-bluetooth-state-and-rescan.md) | Stuck "connected" state, scanning never restarts | Can't reconnect |
| [06](06-oarlock-timestamp-origin.md) | Oarlock timestamps not anchored to device clock | Corrupt time axis |
| [07](07-session-replay-performance.md) | Replay chart renders every raw sample | UI freeze |
| [08](08-map-tile-follow-and-filter.md) | Map recenters constantly; distance gate kills track | Unusable map |
| [09](09-setup-field-sync-and-validation.md) | Stale text fields, no validation, per-keystroke writes | Sources vanish silently |
| [10](10-boat-setup-layout.md) | Seat chips overflow for an eight | Render error |
| [11](11-destructive-action-confirmation.md) | One-tap irreversible session delete | Data loss |
| [12](12-orphaned-session-cleanup.md) | Killed recordings leak invisible directories | Storage growth |
| [13](13-crew-stroke-stall.md) | Crew metrics freeze if one oarlock stops | Metrics stop |

## Priority 2 — UX, polish, hygiene

| # | Task | Impact |
|---|------|--------|
| [14](14-wakelock.md) | Screen sleeps mid-outing | Blocks core use |
| [15](15-user-feedback.md) | `FToaster` wired but never used | No feedback |
| [16](16-unit-display-labels.md) | Raw enum names shown as units | Looks unfinished |
| [17](17-home-screen.md) | Double `FScaffold`, vague Start, no status | First impression |
| [18](18-connected-devices-screen.md) | Dead chevron, no scan/forget/RSSI | Feels broken |
| [19](19-dashboard-grid-capacity.md) | Fixed 4×8, silent tile overlap | Confusing |
| [20](20-theme-and-accessibility.md) | Hardcoded colours, 8 px text, small targets | Sunlight legibility |
| [21](21-history-screen.md) | No swipe-delete, refresh or filter | Friction |
| [22](22-auto-record-toggle.md) | Auto-start can't be turned off | Unwanted sessions |
| [23](23-housekeeping.md) | Dead code, dispose order, dir typo, i18n | Maintainability |

## Suggested order

1. **01, 02** — stop losing user data.
2. **03, 04, 05, 06** — the dashboard and telemetry pipeline behaving correctly.
3. **14, 15, 16** — cheap, and they change how finished the app feels on the water.
4. Everything else as capacity allows.
