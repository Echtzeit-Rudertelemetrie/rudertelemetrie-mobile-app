import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/models/measurement.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/source_catalog.dart';

abstract class DataSource {
  SourceInfo? _info;

  String get name;
  Unit get unit;
  DateTime get startTime;
  Stream<Measurement> get data;

  /// Label of the owning oarlock/boat this source belongs to, or null when the
  /// source is not tied to a connected device.
  String? get group => null;

  /// How this source presents itself to a user choosing one: a label without
  /// the device suffix, what it measures, and which section it belongs to.
  SourceInfo get info => _info ??= sourceInfoFor(name, group: group);

  /// True for a source the app derives from a source the user already picked,
  /// rather than one they pick themselves. A picker leaves these out — they are
  /// an option on another source, not an entry of their own.
  bool get derived => false;

  /// Why this source can stay silent even though its inputs are healthy — it
  /// only emits once some condition is met. Tiles show it in place of an empty
  /// chart, which is otherwise indistinguishable from a broken binding. Null
  /// for a source that streams continuously.
  String? get idleHint => null;

  void dispose();
}
