import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/angle_velocity.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_settings.dart';

/// The shared angle→ω transform (force-power §2, stroke-detection §1.2): emits
/// smoothed angular velocity `ω` (rad/s) at the angle source's timestamps, so it
/// aligns with `Force`/`Angle` for the power sources.
class AngularVelocitySource extends DataSource {
  final String _name;
  final String? _group;
  final DataSource angle;

  final AngleDifferentiator _diff = AngleDifferentiator(
    StrokeSettings.angleLpfCutoffHz,
  );
  final StreamController<Measurement> _controller =
      StreamController.broadcast();
  late final StreamSubscription<Measurement> _sub;

  @override
  late final DateTime startTime;

  AngularVelocitySource({
    required String name,
    required this.angle,
    String? group,
  }) : _name = name,
       _group = group {
    startTime = DateTime.now();
    _sub = angle.data.listen((m) {
      final omega = _diff.add(m.value, m.timestamp);
      _controller.add(Measurement(value: omega, timestamp: m.timestamp));
    });
  }

  @override
  String get name => _name;

  @override
  Unit get unit => Unit.radps;

  @override
  String? get group => _group;

  @override
  Stream<Measurement> get data => _controller.stream;

  @override
  void dispose() {
    _sub.cancel();
    _controller.close();
  }
}
