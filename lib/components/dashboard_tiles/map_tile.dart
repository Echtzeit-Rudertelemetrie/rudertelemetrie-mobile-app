import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/source_binder.dart';
import 'package:rudertelemetrie_mobile_app/services/kinematics/gps_kinematics.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// OSM-backed map of the boat position + session track (widget-map spec).
/// Uses `flutter_map` with its built-in long-term tile caching (v8.2.0+): tiles
/// browsed while online are served offline afterwards. The live track always
/// draws even without tiles. True rectangle bulk pre-download would need FMTC
/// (GPL) — deferred.
class MapTile extends StatefulWidget {
  final DataSourceRegistry registry;

  const MapTile({super.key, required this.registry});

  @override
  State<MapTile> createState() => _MapTileState();
}

class _MapTileState extends State<MapTile> {
  static const _maxPoints = 5000;

  /// Consecutive implausible fixes after which the track resumes in a new
  /// segment. Rejecting forever would kill the track for the rest of the outing.
  static const _maxRejections = 5;

  final MapController _controller = MapController();
  final List<List<LatLng>> _segments = [];
  late final SourceBinder _binder;

  Measurement? _pendingLat;
  DateTime? _lastAcceptedAt;
  int _rejections = 0;
  bool _mapReady = false;
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    _binder = SourceBinder(widget.registry, onChanged: _onSourcesChanged);
    _binder.bind(
      'lat',
      matches: byNamePrefix('Latitude'),
      onData: (m) => _pendingLat = m,
    );
    _binder.bind(
      'lon',
      matches: byNamePrefix('Longitude'),
      onData: _onLongitude,
    );
  }

  @override
  void dispose() {
    _binder.dispose();
    super.dispose();
  }

  /// The track is kept across a dropout — it is session history, not live state.
  /// Only the half-finished fix is discarded so lat/lon cannot pair across the
  /// gap.
  void _onSourcesChanged() {
    _pendingLat = null;
    if (mounted) setState(() {});
  }

  void _onLongitude(Measurement lon) {
    final lat = _pendingLat;
    if (lat == null || lat.timestamp != lon.timestamp) return;
    _addFix(LatLng(lat.value, lon.value), lon.timestamp);
  }

  LatLng? get _lastPoint => _segments.isEmpty ? null : _segments.last.last;

  bool get _hasFix => _lastPoint != null;

  void _addFix(LatLng fix, DateTime time) {
    if (!_isPlausible(fix, time)) {
      if (++_rejections < _maxRejections) return;
      _segments.add([]); // signal loss is over; resume rather than dead-end
    }
    _rejections = 0;
    _append(fix, time);

    if (!mounted) return;
    setState(() {});
    if (_follow && _mapReady) _controller.move(fix, _controller.camera.zoom);
  }

  /// A speed gate, not a distance gate: a 15 s gap at boat speed covers 75 m of
  /// real travel, which a fixed distance threshold would reject as a glitch.
  /// Shares [GpsKinematics.maxPlausibleSpeedMps] so the map and the distance
  /// estimator agree on what a teleport is.
  bool _isPlausible(LatLng fix, DateTime time) {
    final last = _lastPoint;
    final lastAt = _lastAcceptedAt;
    if (last == null || lastAt == null) return true;

    final seconds = time.difference(lastAt).inMicroseconds / 1e6;
    if (seconds <= 0) return false;
    final meters = haversineMeters(
      last.latitude,
      last.longitude,
      fix.latitude,
      fix.longitude,
    );
    return meters / seconds <= GpsKinematics.maxPlausibleSpeedMps;
  }

  void _append(LatLng fix, DateTime time) {
    if (_segments.isEmpty) _segments.add([]);
    _segments.last.add(fix);
    _lastAcceptedAt = time;
    _trimToCapacity();
  }

  void _trimToCapacity() {
    var total = _segments.fold(0, (sum, segment) => sum + segment.length);
    while (total > _maxPoints && _segments.isNotEmpty) {
      _segments.first.removeAt(0);
      if (_segments.first.isEmpty && _segments.length > 1) {
        _segments.removeAt(0);
      }
      total--;
    }
  }

  void _recentre() {
    setState(() => _follow = true);
    final fix = _lastPoint;
    if (fix != null && _mapReady) {
      _controller.move(fix, _controller.camera.zoom);
    }
  }

  /// Only a gesture disengages follow — the programmatic recentre must not.
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture || !_follow) return;
    setState(() => _follow = false);
  }

  @override
  Widget build(BuildContext context) {
    final center = _lastPoint ?? const LatLng(47.66, 9.18);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              onMapReady: () => _mapReady = true,
              onPositionChanged: _onPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'de.htwg.rudertelemetrie_mobile_app',
              ),
              PolylineLayer(
                polylines: [
                  for (final segment in _segments)
                    if (segment.length >= 2)
                      Polyline(
                        points: segment,
                        strokeWidth: 3,
                        color: AppPalette.accent,
                      ),
                ],
              ),
              if (_hasFix) _boatMarker(_lastPoint!),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (!_hasFix)
            const Center(
              child: Text(
                'Waiting for GPS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: AppTypeScale.caption,
                ),
              ),
            ),
          if (!_follow) _recentreButton(),
        ],
      ),
    );
  }

  Widget _boatMarker(LatLng position) => MarkerLayer(
    markers: [
      Marker(
        point: position,
        width: 16,
        height: 16,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.accent,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _recentreButton() => Positioned(
    right: 6,
    bottom: 6,
    child: GestureDetector(
      onTap: _recentre,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.my_location, color: Colors.white, size: 20),
      ),
    ),
  );
}
