import 'package:flutter/foundation.dart';
import 'dashboard_layout_engine.dart';
import 'dashboard_preset.dart';
import 'dashboard_preset_store.dart';
import 'widget_config.dart';

/// Holds the dashboard layout the user currently sees, plus the named presets
/// they can swap between. The active preset's layout *is* the live layout —
/// every edit is written back to it and persisted through [store].
class DashboardModel extends ChangeNotifier {
  static const int _cols = 4;

  /// Rows visible without scrolling. The grid grows past this and scrolls, so a
  /// full dashboard never has to stack tiles on top of each other.
  static const int viewportRows = 8;

  /// Hard ceiling, so a runaway layout cannot grow without bound.
  static const int maxRows = 64;

  static const String defaultPresetName = 'Default';

  final DashboardPresetStore? store;

  List<DashboardPreset> _presets = [];
  String? _activeId;
  List<WidgetConfig> _layout = [];
  bool _editMode = false;

  DashboardModel({this.store});

  int get cols => _cols;

  /// Height of the grid in rows: enough for what is on it, never less than a
  /// viewport, so there is always somewhere to drag a tile.
  int get rows {
    var needed = viewportRows;
    for (final item in _layout) {
      if (item.y + item.h > needed) needed = item.y + item.h;
    }
    return needed.clamp(viewportRows, maxRows);
  }

  DashboardLayoutEngine get _engine =>
      DashboardLayoutEngine(cols: _cols, rows: rows);

  bool get editMode => _editMode;
  List<WidgetConfig> get layout => List.unmodifiable(_layout);

  List<DashboardPreset> get presets => List.unmodifiable(_presets);
  String? get activePresetId => _activeId;

  DashboardPreset? get activePreset {
    final index = _indexOf(_activeId);
    return index == -1 ? null : _presets[index];
  }

  /// Restores the saved presets, falling back to a single empty default so the
  /// model always has an active preset to edit.
  Future<void> load() async {
    final data = await store?.load();
    _presets = data?.presets.toList() ?? [];
    if (_presets.isEmpty) _presets = [_newPreset(defaultPresetName)];
    _activate(data?.activeId ?? _presets.first.id);
    notifyListeners();
  }

  void toggleEditMode() {
    _editMode = !_editMode;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Layout editing — every mutation writes through to the active preset.
  // ---------------------------------------------------------------------------

  void moveWidget(String id, int x, int y) =>
      _commit(_engine.moveElement(_layout, id, x, y));

  void resizeWidget(String id, int w, int h) =>
      _commit(_engine.resizeElement(_layout, id, w, h));

  /// Places [widget] in the first free slot, growing the grid if the visible
  /// rows are full. Returns false only when the [maxRows] ceiling leaves no
  /// room — the caller says so rather than letting the tile land under another.
  bool addWidget(WidgetConfig widget) {
    final engine = DashboardLayoutEngine(
      cols: _cols,
      rows: (rows + widget.h).clamp(1, maxRows),
    );
    final next = engine.addWidget(_layout, widget);
    if (engine.getAllCollisions(_layout, next.last).isNotEmpty) return false;
    _commit(next);
    return true;
  }

  void removeWidget(String id) => _commit(_engine.removeWidget(_layout, id));

  /// Replace an existing widget's config in-place (identified by [newConfig.id]).
  ///
  /// Use this to update app-defined [WidgetConfig.data] without touching the
  /// widget's grid position.
  void updateWidget(WidgetConfig newConfig) {
    final index = _layout.indexWhere((e) => e.id == newConfig.id);
    if (index == -1) return;
    _commit(List.of(_layout)..[index] = newConfig);
  }

  // ---------------------------------------------------------------------------
  // Presets
  // ---------------------------------------------------------------------------

  /// Swap the visible dashboard to [id]. Unknown ids are ignored.
  void selectPreset(String id) {
    if (id == _activeId || _indexOf(id) == -1) return;
    _activate(id);
    _persist();
    notifyListeners();
  }

  /// Add a preset and switch to it. With [copyCurrent] it starts as a copy of
  /// the visible layout, otherwise empty.
  void createPreset(String name, {bool copyCurrent = false}) {
    final preset = _newPreset(name, layout: copyCurrent ? _layout : const []);
    _presets = [..._presets, preset];
    _activate(preset.id);
    _persist();
    notifyListeners();
  }

  void renamePreset(String id, String name) {
    final index = _indexOf(id);
    final trimmed = name.trim();
    if (index == -1 || trimmed.isEmpty) return;
    _presets = List.of(_presets)
      ..[index] = _presets[index].copyWith(name: trimmed);
    _persist();
    notifyListeners();
  }

  /// Remove a preset. The last remaining one is kept — the dashboard always has
  /// somewhere to put tiles.
  void deletePreset(String id) {
    if (_presets.length <= 1 || _indexOf(id) == -1) return;
    _presets = _presets.where((p) => p.id != id).toList();
    if (id == _activeId) _activate(_presets.first.id);
    _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  DashboardPreset _newPreset(
    String name, {
    List<WidgetConfig> layout = const [],
  }) {
    final trimmed = name.trim();
    return DashboardPreset(
      id: 'preset_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed.isEmpty ? defaultPresetName : trimmed,
      layout: List.of(layout),
    );
  }

  int _indexOf(String? id) => _presets.indexWhere((p) => p.id == id);

  void _activate(String id) {
    _activeId = id;
    final index = _indexOf(id);
    _layout = index == -1 ? [] : List.of(_presets[index].layout);
  }

  void _commit(List<WidgetConfig> layout) {
    _layout = layout;
    _persist();
    notifyListeners();
  }

  void _persist() {
    final index = _indexOf(_activeId);
    if (index != -1) {
      _presets = List.of(_presets)
        ..[index] = _presets[index].copyWith(layout: _layout);
    }
    store?.save(DashboardPresetData(presets: _presets, activeId: _activeId));
  }
}
