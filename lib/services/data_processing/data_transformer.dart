import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';

abstract class DataTransformer {
  String get name;
  Unit get xUnit;
  Unit get yUnit;
  StreamTransformer<Measurement, List<FlSpot>> get transformer;
}
