import 'dart:async';

import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/models/xy_point.dart';

import 'unit_pair.dart';

abstract class Combinator1 {
  UnitPair units(Unit sourceUnit);
  Stream<XYPoint> call(Stream<Measurement> source);
}

abstract class Combinator2 {
  UnitPair units(Unit s1Unit, Unit s2Unit);
  Stream<XYPoint> call(Stream<Measurement> s1, Stream<Measurement> s2);
}
