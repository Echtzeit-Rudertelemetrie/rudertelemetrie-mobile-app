import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';

abstract class DataSource {
  String get name;
  Unit get unit;
  Stream<Measurement> get data;

  void dispose();
}