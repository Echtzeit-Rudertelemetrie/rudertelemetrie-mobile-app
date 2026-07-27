/// What a stream measures, independent of which device produced it.
///
/// The registry names sources per instance — `Blade Force 1 (A3F2)` — while
/// everything a picker wants to show about one (a readable label, what the
/// number means, where it belongs) is a property of the metric alone. Those
/// live here, once per metric, instead of at the ~60 places a source is built.
library;

/// The section a source belongs to, stable across devices and sessions.
/// [DataSource.group] names the concrete device; this names the kind.
enum SourceCategory {
  boat('Boat'),
  oarlock('Oarlock'),
  stroke('Stroke'),
  session('Session'),
  other('Other');

  final String label;

  const SourceCategory(this.label);
}

/// Everything shown about a source that is not its live value.
class SourceInfo {
  /// The source's name without the sensor/device suffix its group already
  /// states — `Blade Force`, not `Blade Force 1 (A3F2)`.
  final String label;

  final String? description;
  final SourceCategory category;

  const SourceInfo({
    required this.label,
    required this.category,
    this.description,
  });
}

/// The catalog entry for one metric. The label is the map key, so a metric is
/// named exactly once.
class _Metric {
  final SourceCategory category;
  final String description;

  const _Metric(this.category, this.description);
}

const _oarlock = SourceCategory.oarlock;
const _boat = SourceCategory.boat;
const _stroke = SourceCategory.stroke;
const _session = SourceCategory.session;

const Map<String, _Metric> _catalog = {
  // Measured per oarlock.
  'Force': _Metric(
    _oarlock,
    'Force at the oarlock pin, as the sensor reads it.',
  ),
  'Angle': _Metric(
    _oarlock,
    "Oar angle, corrected for the boat's own rotation.",
  ),
  'Raw Angle': _Metric(
    _oarlock,
    'Oar angle straight from the sensor, uncorrected.',
  ),

  // Derived per oarlock from the rig geometry.
  'Handle Force': _Metric(
    _oarlock,
    'Force at the handle, scaled by the outer lever.',
  ),
  'Blade Force': _Metric(
    _oarlock,
    'Force at the blade, scaled by the inner lever.',
  ),
  'Effective Force': _Metric(
    _oarlock,
    'The part of the blade force pointing along the boat.',
  ),
  'Lateral Force': _Metric(
    _oarlock,
    'The part of the blade force pushing sideways — wasted.',
  ),
  'Angular Velocity': _Metric(
    _oarlock,
    'How fast the oar sweeps through the water, smoothed.',
  ),
  'Power': _Metric(_oarlock, 'Power the rower puts into the handle.'),
  'Propulsion Power': _Metric(
    _oarlock,
    'The share of that power actually driving the boat forward.',
  ),
  'Blade Slip': _Metric(
    _oarlock,
    'How fast the blade slips through the water instead of holding it.',
  ),
  'Blade Efficiency': _Metric(
    _oarlock,
    'Share of blade movement that moves the boat rather than water.',
  ),

  // One value per stroke, per oarlock.
  'Avg Power / Stroke': _Metric(
    _oarlock,
    'Mean power over each full stroke cycle.',
  ),
  'Peak Power / Stroke': _Metric(
    _oarlock,
    'Highest power reached in each stroke cycle.',
  ),
  'Work / Stroke': _Metric(
    _oarlock,
    'Energy delivered over each full stroke cycle.',
  ),
  'Avg Drive Force': _Metric(
    _oarlock,
    'Mean pin force over the drive, catch to finish.',
  ),
  'Peak Force / Stroke': _Metric(
    _oarlock,
    'Highest pin force reached during each drive.',
  ),
  'Blade Drift / Stroke': _Metric(
    _oarlock,
    'Distance the blade slips through the water per drive.',
  ),

  // Boat device: GPS and IMU.
  'Speed': _Metric(_boat, 'Boat speed over ground, from GPS.'),
  'Latitude': _Metric(_boat, 'GPS latitude of the boat.'),
  'Longitude': _Metric(_boat, 'GPS longitude of the boat.'),
  'Acceleration X': _Metric(_boat, 'Boat acceleration along the IMU X axis.'),
  'Acceleration Y': _Metric(_boat, 'Boat acceleration along the IMU Y axis.'),
  'Acceleration Z': _Metric(_boat, 'Boat acceleration along the IMU Z axis.'),
  'Boat Roll': _Metric(_boat, 'IMU roll axis — sideways tilt of the boat.'),
  'Boat Pitch': _Metric(
    _boat,
    'IMU pitch axis. On the installed sensor this reads heading.',
  ),
  'Boat Yaw': _Metric(_boat, 'IMU yaw axis.'),

  // Crew-level, one value per detected stroke.
  'Stroke Rate': _Metric(_stroke, 'Strokes per minute across the crew.'),
  'Stroke Count': _Metric(_stroke, 'Strokes counted so far.'),
  'Drive:Recovery Ratio': _Metric(
    _stroke,
    'Drive time divided by recovery time.',
  ),
  'Reversal→Catch Time': _Metric(
    _stroke,
    'Time from the oar reversing direction to the catch.',
  ),
  'Distance per Stroke': _Metric(
    _stroke,
    'Boat distance covered by the last stroke.',
  ),
  'Catch Angle': _Metric(
    _stroke,
    'Oar angle at the catch, averaged over the crew.',
  ),
  'Finish Angle': _Metric(
    _stroke,
    'Oar angle at the finish, averaged over the crew.',
  ),
  'Sweep': _Metric(_stroke, 'Arc rowed — catch angle minus finish angle.'),
  'Crew Sync (finish)': _Metric(
    _stroke,
    "Spread between the crew's finish times.",
  ),
  'Oarlocks Rowing': _Metric(
    _stroke,
    'How many oarlocks reported the last stroke.',
  ),

  // Recording session totals.
  'Speed (km/h)': _Metric(
    _session,
    "Boat speed from the recording's GPS track.",
  ),
  'Pace (/500m)': _Metric(
    _session,
    'Time to cover 500 m at the current speed.',
  ),
  'Distance': _Metric(
    _session,
    'Distance covered since the recording started.',
  ),
  'Elapsed': _Metric(_session, 'Time since the recording started.'),
};

/// The sensor index and device tag appended to an instance's name — ` 1 (A3F2)`
/// or just ` (A3F2)`. Device tags are at most four alphanumerics, which keeps
/// this off names that end in a real parenthesis, like `Pace (/500m)`.
final _instanceSuffix = RegExp(r'(?: \d+)?(?: \([A-Za-z0-9]{1,4}\))?$');

/// The catalog entry for [name], matched whole and then again with the instance
/// suffix stripped. An unknown metric falls back to its own name and to the
/// category its [group] implies, so a source added later still reads sensibly.
SourceInfo sourceInfoFor(String name, {String? group}) {
  final exact = _catalog[name];
  if (exact != null) {
    return SourceInfo(
      label: name,
      category: exact.category,
      description: exact.description,
    );
  }

  final metric = name.replaceFirst(_instanceSuffix, '');
  final entry = _catalog[metric];
  return SourceInfo(
    label: metric,
    category: entry?.category ?? _categoryOfGroup(group),
    description: entry?.description,
  );
}

SourceCategory _categoryOfGroup(String? group) {
  if (group == null) return SourceCategory.other;
  if (group.startsWith('Oarlock') || group.startsWith('Force & Power')) {
    return SourceCategory.oarlock;
  }
  if (group.startsWith('Boat')) return SourceCategory.boat;
  if (group.startsWith('Stroke')) return SourceCategory.stroke;
  if (group.startsWith('Session')) return SourceCategory.session;
  return SourceCategory.other;
}
