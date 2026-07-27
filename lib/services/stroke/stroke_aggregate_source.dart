import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_event.dart';

/// How a per-stroke aggregate reduces a base sample stream over a cycle
/// (force-power-model §6). Cycle = previous finish → finish; drive = catch →
/// finish.
enum StrokeAggregate {
  peakOverDrive,
  peakOverCycle,
  averageOverDrive,
  averageOverCycle,
  integralOverDrive,
  integralOverCycle,
}

class _Sample {
  final DateTime t;
  final double value;
  const _Sample(this.t, this.value);
}

/// Emits one [Measurement] per stroke: an aggregate of [base] over the cycle or
/// drive interval bounded by this oarlock's catch/finish events (force-power §6).
/// Integrals use the trapezoidal rule over the irregular sample timestamps.
class StrokeGatedAggregateSource extends DataSource {
  static const _retain = Duration(seconds: 30);

  final String _name;
  final Unit _unit;
  final String? _group;
  final DataSource base;
  final Stream<StrokeEvent> events;
  final String oarlockKey;
  final StrokeAggregate mode;

  final StreamController<Measurement> _controller =
      StreamController.broadcast();
  final List<_Sample> _buffer = [];
  late final StreamSubscription<Measurement> _baseSub;
  late final StreamSubscription<StrokeEvent> _eventSub;

  DateTime? _catch;
  DateTime? _previousFinish;

  @override
  late final DateTime startTime;

  StrokeGatedAggregateSource({
    required String name,
    required Unit unit,
    required this.base,
    required this.events,
    required this.oarlockKey,
    required this.mode,
    String? group,
  }) : _name = name,
       _unit = unit,
       _group = group {
    startTime = DateTime.now();
    _baseSub = base.data.listen(_onSample);
    _eventSub = events.listen(_onEvent);
  }

  @override
  String get name => _name;

  @override
  Unit get unit => _unit;

  @override
  String? get group => _group;

  @override
  Stream<Measurement> get data => _controller.stream;

  bool get _driveBounded =>
      mode == StrokeAggregate.peakOverDrive ||
      mode == StrokeAggregate.averageOverDrive ||
      mode == StrokeAggregate.integralOverDrive;

  void _onSample(Measurement m) {
    _buffer.add(_Sample(m.timestamp, m.value));
    final cutoff = m.timestamp.subtract(_retain);
    while (_buffer.isNotEmpty && _buffer.first.t.isBefore(cutoff)) {
      _buffer.removeAt(0);
    }
  }

  void _onEvent(StrokeEvent event) {
    if (event.oarlockKey != oarlockKey) return;
    if (event.type == StrokeEventType.catch_) {
      _catch = event.time;
    } else if (event.type == StrokeEventType.finish) {
      _closeCycle(event.time);
    }
  }

  void _closeCycle(DateTime finish) {
    final start = _driveBounded ? _catch : _previousFinish;
    if (start != null && finish.isAfter(start)) {
      final value = _reduce(start, finish);
      if (value != null) {
        _controller.add(Measurement(value: value, timestamp: finish));
      }
    }
    _previousFinish = finish;
    _catch = null;
    _buffer.removeWhere((s) => s.t.isBefore(finish));
  }

  double? _reduce(DateTime start, DateTime finish) {
    final window = _buffer
        .where((s) => !s.t.isBefore(start) && !s.t.isAfter(finish))
        .toList();
    if (window.isEmpty) return null;

    return switch (mode) {
      StrokeAggregate.peakOverDrive || StrokeAggregate.peakOverCycle =>
        window.map((s) => s.value).reduce((a, b) => a > b ? a : b),
      StrokeAggregate.integralOverDrive ||
      StrokeAggregate.integralOverCycle => _integral(window),
      StrokeAggregate.averageOverDrive || StrokeAggregate.averageOverCycle =>
        _integral(window) / (finish.difference(start).inMicroseconds / 1e6),
    };
  }

  double _integral(List<_Sample> samples) {
    var sum = 0.0;
    for (var i = 1; i < samples.length; i++) {
      final dt = samples[i].t.difference(samples[i - 1].t).inMicroseconds / 1e6;
      sum += 0.5 * (samples[i].value + samples[i - 1].value) * dt;
    }
    return sum;
  }

  @override
  void dispose() {
    _baseSub.cancel();
    _eventSub.cancel();
    _controller.close();
  }
}
