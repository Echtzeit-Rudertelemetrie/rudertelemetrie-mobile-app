import 'package:rudertelemetrie_mobile_app/constants/unit.dart';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Formats a session duration as `m:ss`, promoting to `h:mm:ss` from one hour.
/// A five-minute piece reads `5:23`, not `0:05:23`.
String formatElapsed(Duration d) {
  final seconds = _twoDigits(d.inSeconds.abs() % 60);
  final minutes = d.inMinutes.abs() % 60;
  if (d.inHours.abs() == 0) {
    return '${d.isNegative ? '-' : ''}$minutes:$seconds';
  }
  return '${d.inHours}:${_twoDigits(minutes)}:$seconds';
}

/// Formats a distance in metres as `m` below 1 km, else `km` with two decimals.
String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(2)} km';

/// Formats a pace in seconds per 500 m as `m:ss` — nobody reads pace in decimal
/// seconds. Non-finite or non-positive input has no meaningful pace.
String formatPace(double secondsPer500m) {
  if (!secondsPer500m.isFinite || secondsPer500m <= 0) return '—';
  // Truncated, like a clock: 2:08.5 reads as 2:08, never 2:09.
  final total = secondsPer500m.floor();
  return '${total ~/ 60}:${_twoDigits(total % 60)}';
}

/// Renders [value] the way its [unit] should read on a tile.
String formatValue(double value, Unit unit) => switch (unit) {
  Unit.pace => formatPace(value),
  _ => value.toStringAsFixed(1),
};
