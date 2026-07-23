# Spec: Map view (GPS track)

**Importance:** Optional / Very nice-to-have (PO: "Karte mit Position (OpenStreetMap?),
wenn wir eh schon GPS haben (optional)").
**Complexity:** High (tiles, offline, new dependency)
**Depends on:** GPS lat/lon exposed as data (currently decoded but **not** registered).

## What

An OpenStreetMap-backed map showing current boat position and the session track.

## Prerequisite: expose GPS position

`GpsSample.latitude/longitude` (firmware ×1e6 degrees, ~0.11 m resolution) are decoded in
`bluetooth_packet_decode_util.dart` but `bluetooth_stream_handler._handleBoat` only
registers `Speed` + accel. Add `Latitude` / `Longitude` (and optionally `Course`,
`Satellites`, `GPS Valid`) sources, or a dedicated position stream the map subscribes to.
This is the small, reusable part — it also feeds **distance-by-haversine** and, because the
firmware transmits only integer-truncated m/s, the **position-derived speed** that
pace/speed/distance all rely on (kinematics §1, [`recording-session.md`](recording-session.md)).
So exposing position is worth doing early even independently of the map.

## Approach — cached offline region

On-water there is usually no connectivity, so the map targets **pre-cached offline tiles**
rather than live fetching:

- Let the user **pre-download a tile region** (their rowing venue) while online — pick an
  area + zoom range, cache the OSM raster tiles locally, show cache size.
- On the water the `MapTile` renders **from the local cache only** (no network calls); the
  live track always draws even outside cached bounds.
- Graceful tiers: cached tiles where available → bare **track polyline on a blank canvas**
  outside the cached region / before any download. (Track-only is effectively the
  no-cache fallback, so it comes for free.)

## Rendering

- `MapTile` (`CustomPaint`-style tile, own subscription) built on **`flutter_map`** with
  **`flutter_map_tile_caching` (FMTC)** as the offline store (verify current versions/API
  via Context7 before implementing).
- Draw the live position marker + a polyline of the session track (from the same GPS fix
  buffer used for haversine distance).
- Auto-follow the marker; pinch/zoom.
- **Region picker**: user drags a rectangle on the map + chooses a zoom range, then
  downloads with a progress bar and a size estimate; downloaded regions are listed for
  delete/refresh.

## Constraints & caveats

- **Tile sourcing / attribution**: OSM tile-usage policy and attribution requirements apply
  even for pre-caching — use a provider that permits bulk download and show the attribution.
  Pick the tile provider before shipping (a key/provider account may be needed).
- **Cache management**: bound cache size; let the user delete/refresh regions.
- Filter invalid/glitchy fixes (`valid == false`, implausible jumps) exactly as the
  haversine distance does.
