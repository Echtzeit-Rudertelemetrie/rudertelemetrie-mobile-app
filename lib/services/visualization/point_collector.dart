import 'dart:async';

import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';

import 'unit_pair.dart';

abstract class PointCollector {
  UnitPair Function(UnitPair) get unitTransform;
  StreamTransformer<XYPoint, List<XYPoint>> get collector;

  /// Why this collector can hold back every point while its input streams
  /// normally — it is gated on a stroke, a drive, or a threshold crossing.
  /// Surfaced by the tile instead of an indefinitely empty chart. Null for a
  /// collector that passes everything through.
  String? get idleHint => null;
}
