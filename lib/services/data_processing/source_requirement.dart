import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/source_catalog.dart';

/// What a slot needs from a source beyond the source merely existing.
///
/// Offering a stream that cannot produce anything sensible is worse than not
/// offering it: the tile lands on the dashboard looking broken, and nothing
/// says why. The picker filters on this instead.
enum SourceRequirement {
  /// Any stream will do.
  any(emptyMessage: 'No streams available.'),

  /// One value per completed stroke. Anything indexing by stroke number needs
  /// this, or it counts samples and calls them strokes.
  perStroke(
    emptyMessage:
        'No per-stroke streams yet — they appear once strokes are detected.',
  ),

  /// An oar angle from an oarlock, in degrees. The angle dial is drawn around
  /// the catch and finish of a scull, so a latitude or a boat roll on it is
  /// not a reading, just a needle.
  oarAngle(emptyMessage: 'No oarlock angle streams available.');

  /// Shown in place of the list when nothing satisfies this requirement.
  final String emptyMessage;

  const SourceRequirement({required this.emptyMessage});

  bool accepts(DataSource source) => switch (this) {
    SourceRequirement.any => true,
    SourceRequirement.perStroke => source.perStroke,
    SourceRequirement.oarAngle =>
      source.info.category == SourceCategory.oarlock && source.unit == Unit.deg,
  };
}
