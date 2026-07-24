import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/kinematics/gps_kinematics.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_record.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

enum SessionState { idle, recording, stopped }

/// Owns the single recording origin and lifecycle (idle → recording → stopped),
/// the session clock, position-derived speed/distance, and the derived
/// `Speed (km/h)`/`Pace`/`Distance`/`Elapsed` sources. Phase 0 is manual-only;
/// auto-start hooks onto the stroke engine in a later phase.
class RecordingSession extends ChangeNotifier {
  static const _paceSpeedFloorMps = 0.3;
  static const _tick = Duration(seconds: 1);

  final DataSourceRegistry registry;
  final SessionStore? store;
  final GpsKinematics _kinematics = GpsKinematics();

  late final PushDataSource _speedKmh;
  late final PushDataSource _pace;
  late final PushDataSource _distance;
  late final PushDataSource _elapsedSource;

  SessionState _state = SessionState.idle;
  StartMode _startMode = StartMode.manual;
  DateTime? _startedAt;
  DateTime? _stoppedAt;

  double _sessionDistanceMeters = 0;
  Measurement? _pendingLat;

  DataSource? _latSource;
  DataSource? _lonSource;
  StreamSubscription<Measurement>? _latSub;
  StreamSubscription<Measurement>? _lonSub;
  Timer? _ticker;

  double _speedWeightedSum = 0;
  double _peakSpeedKmh = 0;
  DateTime? _lastSpeedTime;
  double? _lastSpeedKmh;

  RecordingSession({required this.registry, this.store}) {
    _speedKmh = _register('Speed (km/h)', Unit.kmh);
    _pace = _register('Pace (/500m)', Unit.s);
    _distance = _register('Distance', Unit.m);
    _elapsedSource = _register('Elapsed', Unit.s);
    registry.addListener(_bindGpsSources);
    _bindGpsSources();
  }

  SessionState get state => _state;
  StartMode get startMode => _startMode;
  bool get isRecording => _state == SessionState.recording;
  DateTime? get startedAt => _startedAt;
  double get speedMps => _kinematics.speedMps;
  double get distanceMeters => _sessionDistanceMeters;

  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    return (_stoppedAt ?? DateTime.now()).difference(start);
  }

  void start({StartMode mode = StartMode.manual}) {
    if (isRecording) return;
    _startMode = mode;
    _startedAt = DateTime.now();
    _stoppedAt = null;
    _state = SessionState.recording;
    _resetAccumulators();
    _ticker = Timer.periodic(_tick, (_) => _onTick());
    unawaited(store?.beginSession(_currentInfo()));
    notifyListeners();
  }

  void stop() {
    if (!isRecording) return;
    _stoppedAt = DateTime.now();
    _state = SessionState.stopped;
    _ticker?.cancel();
    _ticker = null;
    unawaited(store?.finishSession(_buildSummary()));
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _state = SessionState.idle;
    _startedAt = null;
    _stoppedAt = null;
    _resetAccumulators();
    unawaited(store?.abortSession());
    notifyListeners();
  }

  void _resetAccumulators() {
    _kinematics.reset();
    _sessionDistanceMeters = 0;
    _pendingLat = null;
    _speedWeightedSum = 0;
    _peakSpeedKmh = 0;
    _lastSpeedTime = null;
    _lastSpeedKmh = null;
  }

  SessionInfo _currentInfo() => SessionInfo(
        id: 'session_${_startedAt!.millisecondsSinceEpoch}',
        startedAt: _startedAt!,
        startMode: _startMode,
      );

  SessionSummary _buildSummary() {
    final seconds = elapsed.inMicroseconds / 1e6;
    final avgSpeed = seconds > 0 ? _speedWeightedSum / seconds : 0.0;
    return SessionSummary(
      info: _currentInfo(),
      stoppedAt: _stoppedAt!,
      distanceMeters: _sessionDistanceMeters,
      averages: {'Speed (km/h)': avgSpeed},
      peaks: {'Speed (km/h)': _peakSpeedKmh},
    );
  }

  void _onTick() {
    _elapsedSource.add(
      Measurement(value: elapsed.inSeconds.toDouble(), timestamp: DateTime.now()),
    );
    notifyListeners();
  }

  void _bindGpsSources() {
    final lat = _find('Latitude');
    final lon = _find('Longitude');
    if (lat != _latSource) {
      _latSub?.cancel();
      _latSource = lat;
      _latSub = lat?.data.listen((m) => _pendingLat = m);
    }
    if (lon != _lonSource) {
      _lonSub?.cancel();
      _lonSource = lon;
      _lonSub = lon?.data.listen(_onLongitude);
    }
  }

  DataSource? _find(String prefix) {
    for (final source in registry.all) {
      if (source.name.startsWith(prefix)) return source;
    }
    return null;
  }

  void _onLongitude(Measurement lon) {
    final lat = _pendingLat;
    if (lat == null || lat.timestamp != lon.timestamp) return;
    _onFix(GpsFix(latitude: lat.value, longitude: lon.value, time: lon.timestamp));
  }

  void _onFix(GpsFix fix) {
    final step = _kinematics.add(fix);
    final speedKmh = step.speedMps * 3.6;
    _speedKmh.add(Measurement(value: speedKmh, timestamp: fix.time));
    if (step.speedMps >= _paceSpeedFloorMps) {
      _pace.add(Measurement(value: 500 / step.speedMps, timestamp: fix.time));
    }
    if (!isRecording || !step.accepted) return;
    _sessionDistanceMeters += step.stepMeters;
    _distance.add(Measurement(value: _sessionDistanceMeters, timestamp: fix.time));
    _accumulateSpeed(speedKmh, fix.time);
  }

  void _accumulateSpeed(double speedKmh, DateTime time) {
    if (speedKmh > _peakSpeedKmh) _peakSpeedKmh = speedKmh;
    final last = _lastSpeedTime;
    if (last != null) {
      final dt = time.difference(last).inMicroseconds / 1e6;
      _speedWeightedSum += 0.5 * (speedKmh + (_lastSpeedKmh ?? speedKmh)) * dt;
    }
    _lastSpeedTime = time;
    _lastSpeedKmh = speedKmh;
  }

  PushDataSource _register(String name, Unit unit) {
    final source = PushDataSource(name: name, unit: unit, group: 'Session');
    registry.registerDeferred(source);
    return source;
  }

  @override
  void dispose() {
    registry.removeListener(_bindGpsSources);
    _latSub?.cancel();
    _lonSub?.cancel();
    _ticker?.cancel();
    for (final source in [_speedKmh, _pace, _distance, _elapsedSource]) {
      registry.unregister(source.name);
      source.dispose();
    }
    super.dispose();
  }
}
