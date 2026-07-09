/// A single numeric setting a visualizer exposes for per-widget configuration
/// (e.g. the length of a time window or a trigger threshold).
class VisualizerParam {
  final String key;
  final String label;
  final double defaultValue;
  final double min;
  final double? max;

  /// Optional unit suffix shown next to the input field (e.g. 's', 'N').
  final String? unitLabel;

  const VisualizerParam({
    required this.key,
    required this.label,
    required this.defaultValue,
    this.min = 0,
    this.max,
    this.unitLabel,
  });

  double clamp(double value) {
    final upper = max ?? double.infinity;
    return value.clamp(min, upper);
  }
}
