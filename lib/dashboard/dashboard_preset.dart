import 'widget_config.dart';

/// A named, saveable dashboard layout. The user keeps several of these (e.g.
/// "Technique", "Race", "Rig check") and swaps between them without losing the
/// tiles of the others.
class DashboardPreset {
  final String id;
  final String name;
  final List<WidgetConfig> layout;

  const DashboardPreset({
    required this.id,
    required this.name,
    this.layout = const [],
  });

  DashboardPreset copyWith({String? name, List<WidgetConfig>? layout}) =>
      DashboardPreset(
        id: id,
        name: name ?? this.name,
        layout: layout ?? this.layout,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'layout': [for (final w in layout) w.toJson()],
  };

  static DashboardPreset fromJson(Map<String, dynamic> json) => DashboardPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    layout: _layoutFromJson(json['layout']),
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
