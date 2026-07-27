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

  /// Why this source can stay silent even though its inputs are healthy — it
  /// only emits once some condition is met. Tiles show it in place of an empty
  /// chart, which is otherwise indistinguishable from a broken binding. Null
  /// for a source that streams continuously.
  String? get idleHint => null;

  void dispose();
}
