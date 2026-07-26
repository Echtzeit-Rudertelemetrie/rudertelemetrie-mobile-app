import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';

/// A [DataSource] whose value is a function of one or more input sources
/// (architecture §2.1). The first [alignedCount] sources are the aligned
/// trigger group: an output is emitted when they are all present and share a
/// timestamp within [tolerance] (de-duplicated per timestamp, so a 100 Hz
/// force/angle pair yields exactly one sample). Any remaining sources are
/// latest-held — they must have a value but their timestamps are not checked,
/// which lets a lower-rate boat `Speed` feed into oarlock-rate power sources.
/// [alignedCount] defaults to every source.
class CombineLatestSource extends DataSource {
  final String _name;
  final Unit _unit;
  final String? _group;
  final List<DataSource> sources;
  final double Function(List<double> latest) compute;
  final Duration tolerance;
  final int _alignedCount;

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
    int? alignedCount,
    this.tolerance = const Duration(milliseconds: 5),
  })  : _name = name,
        _unit = unit,
        _group = group,
        _alignedCount = alignedCount ?? sources.length {
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
    for (final latest in _latest) {
      if (latest == null) return;
    }

    var reference = _latest[0]!.timestamp;
    for (var i = 1; i < _alignedCount; i++) {
      final ts = _latest[i]!.timestamp;
      if (ts.isAfter(reference)) reference = ts;
    }
    for (var i = 0; i < _alignedCount; i++) {
      if (_latest[i]!.timestamp.difference(reference).abs() > tolerance) return;
    }

    if (_lastEmitted == reference) return;
    _lastEmitted = reference;
    _controller.add(Measurement(
      value: compute([for (final l in _latest) l!.value]),
      timestamp: reference,
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
