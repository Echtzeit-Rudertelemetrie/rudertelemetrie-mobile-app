import 'dart:math' as math;

import 'package:rudertelemetrie_mobile_app/services/stroke/low_pass_differentiator.dart';

/// Smoothed angular velocity `ω` (rad/s) from a noisy degree-angle stream
/// (stroke-detection §1.2).
class AngleDifferentiator {
  static const _degreesToRadians = math.pi / 180;

  final LowPassDifferentiator _differentiator;

  AngleDifferentiator(double cutoffHz)
    : _differentiator = LowPassDifferentiator(cutoffHz);

  double get filteredAngle => _differentiator.filtered;

  double add(double angleDeg, DateTime time) =>
      _degreesToRadians * _differentiator.add(angleDeg, time);

  void reset() => _differentiator.reset();
}
