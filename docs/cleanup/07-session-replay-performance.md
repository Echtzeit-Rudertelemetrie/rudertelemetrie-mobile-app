# 07 — Session replay renders every raw sample and parses on the UI isolate

**Priority:** P1 · **Effort:** M · **Area:** history

## Problem

`SessionDetailScreen` parses the entire `session.csv` on the UI isolate and
hands every parsed sample to `fl_chart` with no decimation.

A 20-minute outing at 100 Hz is ~120,000 samples *per source*, and a session
logs every registered source. Opening such a session will jank badly or lock the
UI outright — and this only shows up with real training data, not test data.

## Evidence

- `lib/screens/session_detail_screen.dart:31-34` — `_loadSeries` calls
  `parseSessionCsv(csv)` directly in the future, no isolate.
- `lib/services/recording/session_store.dart:42-54` — `parseSessionCsv` builds
  the full `Map<String, List<SessionSample>>` in memory.
- `lib/screens/session_detail_screen.dart:150-157` — `_chart` maps every point
  to an `FlSpot` with no downsampling.

## Fix

1. **Parse off the UI isolate.** Wrap in `compute()`. `parseSessionCsv` is
   already a pure top-level function, so it is directly compatible.
2. **Decimate for display.** Reduce the selected series to ~1–2k points before
   building spots. Prefer min/max-per-bucket over naive stride sampling so
   peaks are not lost — for force curves the peak *is* the signal.
3. **Lazy per-source loading.** Only decode the selected source's series rather
   than all of them, or keep the parse but decimate on selection.
4. Consider streaming the CSV line by line rather than `readAsString` on very
   large files.

## Acceptance criteria

- [ ] Opening a 20-minute session with 10+ sources shows the chart in under a
      second with no dropped-frame warnings.
- [ ] Visible peaks in the decimated chart match the raw data (min/max buckets).
- [ ] The source dropdown switches series without re-parsing the file.
- [ ] Benchmark or test asserting the decimated output length is bounded.
