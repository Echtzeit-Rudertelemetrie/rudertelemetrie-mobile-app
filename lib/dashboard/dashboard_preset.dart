import 'dashboard_grid_size.dart';
import 'widget_config.dart';

/// A named, saveable dashboard layout. The user keeps several of these (e.g.
/// "Technique", "Race", "Rig check") and swaps between them without losing the
/// tiles of the others.
class DashboardPreset {
  final String id;
  final String name;
  final List<WidgetConfig> layout;

  /// The grid width [layout]'s coordinates are in. A preset last edited in
  /// landscape is saved on the finer landscape grid, so loading it in portrait
  /// has to scale it back down. Presets written before the grid became
  /// orientation-aware carry no width and are read as portrait.
  final int cols;

  const DashboardPreset({
    required this.id,
    required this.name,
    this.layout = const [],
    this.cols = DashboardGridSize.portraitCols,
  });

  DashboardPreset copyWith({
    String? name,
    List<WidgetConfig>? layout,
    int? cols,
  }) => DashboardPreset(
    id: id,
    name: name ?? this.name,
    layout: layout ?? this.layout,
    cols: cols ?? this.cols,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cols': cols,
    'layout': [for (final w in layout) w.toJson()],
  };

  static DashboardPreset fromJson(Map<String, dynamic> json) => DashboardPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    layout: _layoutFromJson(json['layout']),
    cols: json['cols'] as int? ?? DashboardGridSize.portraitCols,
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
