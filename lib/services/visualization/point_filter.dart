import 'dart:async';

import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';

import 'unit_pair.dart';

abstract class PointFilter {
  UnitPair Function(UnitPair) get unitTransform;
  StreamTransformer<XYPoint, XYPoint> get transformer;
}
