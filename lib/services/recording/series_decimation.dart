import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

/// Reduces [samples] to at most [maxPoints] while keeping the shape of the
/// signal: each bucket contributes its minimum and maximum, so a force peak
/// survives even when thousands of samples collapse into one pixel column.
///
/// Naive stride sampling would drop exactly the peaks that make a force curve
/// worth looking at.
List<SessionSample> decimateSeries(
  List<SessionSample> samples, {
  int maxPoints = 1500,
}) {
  if (maxPoints < 2 || samples.length <= maxPoints) return samples;

  final buckets = maxPoints ~/ 2;
  final result = <SessionSample>[];
  for (var bucket = 0; bucket < buckets; bucket++) {
    final start = bucket * samples.length ~/ buckets;
    final end = (bucket + 1) * samples.length ~/ buckets;
    if (start >= end) continue;
    _addExtremes(result, samples, start, end);
  }
  return result;
}

/// Appends the bucket's extremes in the order they occur, so the series stays
/// monotonic in time.
void _addExtremes(
  List<SessionSample> result,
  List<SessionSample> samples,
  int start,
  int end,
) {
  var lowest = samples[start];
  var highest = samples[start];
  for (var i = start + 1; i < end; i++) {
    final sample = samples[i];
    if (sample.value < lowest.value) lowest = sample;
    if (sample.value > highest.value) highest = sample;
  }
  if (identical(lowest, highest)) {
    result.add(lowest);
    return;
  }
  final first = lowest.elapsedMs <= highest.elapsedMs ? lowest : highest;
  result.add(first);
  result.add(identical(first, lowest) ? highest : lowest);
}
