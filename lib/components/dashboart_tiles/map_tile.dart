import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/kinematics/gps_kinematics.dart';

/// OSM-backed map of the boat position + session track (widget-map spec).
/// Uses `flutter_map` with its built-in long-term tile caching (v8.2.0+): tiles
/// browsed while online are served offline afterwards. The live track always
/// draws even without tiles. Glitch fixes are rejected like the distance
/// estimator. True rectangle bulk pre-download would need FMTC (GPL) — deferred.
class MapTile extends StatefulWidget {
  final DataSourceRegistry registry;

  const MapTile({super.key, required this.registry});

  @override
  State<MapTile> createState() => _MapTileState();
}

class _MapTileState extends State<MapTile> {
  static const _maxJumpMeters = 50.0;
  static const _maxPoints = 5000;

  final MapController _controller = MapController();
  final List<LatLng> _track = [];
  StreamSubscription<Measurement>? _latSub;
  StreamSubscription<Measurement>? _lonSub;
  Measurement? _pendingLat;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void dispose() {
    _latSub?.cancel();
    _lonSub?.cancel();
    super.dispose();
  }

  DataSource? _find(String prefix) {
    for (final s in widget.registry.all) {
      if (s.name.startsWith(prefix)) return s;
    }
    return null;
  }

  void _bind() {
    _latSub = _find('Latitude')?.data.listen((m) => _pendingLat = m);
    _lonSub = _find('Longitude')?.data.listen(_onLongitude);
  }

  void _onLongitude(Measurement lon) {
    final lat = _pendingLat;
    if (lat == null || lat.timestamp != lon.timestamp) return;
    _addFix(LatLng(lat.value, lon.value));
  }

  void _addFix(LatLng fix) {
    if (_track.isNotEmpty) {
      final last = _track.last;
      if (haversineMeters(last.latitude, last.longitude, fix.latitude,
              fix.longitude) >
          _maxJumpMeters) {
        return;
      }
    }
    _track.add(fix);
    if (_track.length > _maxPoints) _track.removeAt(0);
    if (mounted) {
      setState(() {});
      if (_mapReady) _controller.move(fix, _controller.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _track.isNotEmpty ? _track.last : const LatLng(47.66, 9.18);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 15,
          onMapReady: () => _mapReady = true,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'de.htwg.rudertelemetrie_mobile_app',
          ),
          if (_track.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _track,
                  strokeWidth: 3,
                  color: const Color(0xFFF45866),
                ),
              ],
            ),
          if (_track.isNotEmpty)
            MarkerLayer(
              markers: [
                Marker(
                  point: _track.last,
                  width: 16,
                  height: 16,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF45866),
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
    );
  }
}
