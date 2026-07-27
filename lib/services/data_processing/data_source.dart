import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';

abstract class DataSource {
  String get name;
  Unit get unit;
  DateTime get startTime;
  Stream<Measurement> get data;

  /// Label of the owning oarlock/boat this source belongs to, or null when the
  /// source is not tied to a connected device.
  String? get group => null;

  void dispose();
}
