import 'dashboard_grid_size.dart';
import 'widget_config.dart';

/// A named, saveable dashboard layout. The user keeps several of these (e.g.
/// "Technique", "Race", "Rig check") and swaps between them without losing the
/// tiles of the others.
class DashboardPreset {
  final String id;
  final String name;
  final List<WidgetConfig> layout;

  /// The grid [layout]'s coordinates are in. Each orientation divides the grid
  /// differently, so a preset last edited in landscape has to be scaled when it
  /// is loaded in portrait. Presets written before the grid became
  /// orientation-aware carry no size and are read as the coarse grid they were
  /// authored in.
  final int cols;
  final int rows;

  const DashboardPreset({
    required this.id,
    required this.name,
    this.layout = const [],
    this.cols = DashboardGridSize.coarseCols,
    this.rows = DashboardGridSize.coarseRows,
  });

  DashboardPreset copyWith({
    String? name,
    List<WidgetConfig>? layout,
    int? cols,
    int? rows,
  }) => DashboardPreset(
    id: id,
    name: name ?? this.name,
    layout: layout ?? this.layout,
    cols: cols ?? this.cols,
    rows: rows ?? this.rows,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cols': cols,
    'rows': rows,
    'layout': [for (final w in layout) w.toJson()],
  };

  static DashboardPreset fromJson(Map<String, dynamic> json) => DashboardPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    layout: _layoutFromJson(json['layout']),
    cols: json['cols'] as int? ?? DashboardGridSize.coarseCols,
    rows: json['rows'] as int? ?? DashboardGridSize.coarseRows,
  );

  static List<WidgetConfig> _layoutFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map<String, dynamic>) WidgetConfig.fromJson(entry),
    ];
  }
}

/// Everything the preset store persists: the presets themselves plus which one
/// is currently on screen.
class DashboardPresetData {
  final List<DashboardPreset> presets;
  final String? activeId;

  const DashboardPresetData({required this.presets, this.activeId});
}
