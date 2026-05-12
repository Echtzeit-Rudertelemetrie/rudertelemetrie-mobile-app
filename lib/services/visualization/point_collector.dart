import 'dart:async';

import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';

import 'unit_pair.dart';

abstract class PointCollector {
  UnitPair Function(UnitPair) get unitTransform;
  StreamTransformer<XYPoint, List<XYPoint>> get collector;
}
