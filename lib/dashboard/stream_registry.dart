/// A named stream of [double] values displayed in dashboard tiles.
class StreamInfo {
  final String key;
  final String label;
  final String unit;

  /// Optional fixed Y-axis bounds for charts. If null, the chart auto-scales.
  final double? minY;
  final double? maxY;

  final Stream<double> stream;

  const StreamInfo({
    required this.key,
    required this.label,
    required this.unit,
    required this.stream,
    this.minY,
    this.maxY,
  });
}

/// Global registry mapping string keys to live [StreamInfo] records.
///
/// Call [register] when a data source becomes active and [unregister] when
/// it is disposed — the dashboard automatically picks up changes.
class StreamRegistry {
  StreamRegistry._();

  static final Map<String, StreamInfo> _map = {};

  static void register(StreamInfo info) => _map[info.key] = info;

  static void unregister(String key) => _map.remove(key);

  static StreamInfo? get(String key) => _map[key];

  static List<StreamInfo> get all => List.unmodifiable(_map.values.toList());
}
