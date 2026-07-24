import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

/// A [DataSource] whose value is a function of one or more input sources
/// (architecture §2.1). On each input it recomputes from the latest of every
/// source, emitting once all inputs are present and their timestamps align
/// within [tolerance]. Emissions are de-duplicated per triggering timestamp, so
/// a single 100 Hz sample pair (identical force/angle timestamps) yields exactly
/// one output sample.
class CombineLatestSource extends DataSource {
  final String _name;
  final Unit _unit;
  final String? _group;
  final List<DataSource> sources;
  final double Function(List<double> latest) compute;
  final Duration tolerance;

  final StreamController<Measurement> _controller = StreamController.broadcast();
  final List<StreamSubscription<Measurement>> _subs = [];
  late final List<Measurement?> _latest;
  DateTime? _lastEmitted;

  @override
  late final DateTime startTime;

  CombineLatestSource({
    required String name,
    required Unit unit,
    required this.sources,
    required this.compute,
    String? group,
    this.tolerance = const Duration(milliseconds: 5),
  })  : _name = name,
        _unit = unit,
        _group = group {
    startTime = DateTime.now();
    _latest = List<Measurement?>.filled(sources.length, null);
    for (var i = 0; i < sources.length; i++) {
      final index = i;
      _subs.add(sources[i].data.listen((m) => _onInput(index, m)));
    }
  }

  @override
  String get name => _name;

  @override
  Unit get unit => _unit;

  @override
  String? get group => _group;

  @override
  Stream<Measurement> get data => _controller.stream;

  void _onInput(int index, Measurement m) {
    _latest[index] = m;
    final ts = m.timestamp;
    for (final latest in _latest) {
      if (latest == null) return;
      if (latest.timestamp.difference(ts).abs() > tolerance) return;
    }
    if (_lastEmitted == ts) return;
    _lastEmitted = ts;
    _controller.add(Measurement(
      value: compute([for (final l in _latest) l!.value]),
      timestamp: ts,
    ));
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _controller.close();
  }
}
