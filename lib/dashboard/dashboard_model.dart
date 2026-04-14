import 'package:flutter/foundation.dart';
import 'dashboard_layout_engine.dart';
import 'widget_config.dart';

class DashboardModel extends ChangeNotifier {
  static const int _cols = 4;
  static const int _rows = 8;

  final _engine = const DashboardLayoutEngine(cols: _cols, rows: _rows);

  List<WidgetConfig> _layout = [];
  bool _editMode = false;

  int get cols => _cols;
  int get rows => _rows;
  bool get editMode => _editMode;
  List<WidgetConfig> get layout => List.unmodifiable(_layout);

  void toggleEditMode() {
    _editMode = !_editMode;
    notifyListeners();
  }

  void moveWidget(String id, int x, int y) {
    _layout = _engine.moveElement(_layout, id, x, y);
    notifyListeners();
  }

  void resizeWidget(String id, int w, int h) {
    _layout = _engine.resizeElement(_layout, id, w, h);
    notifyListeners();
  }

  void addWidget(WidgetConfig widget) {
    _layout = _engine.addWidget(_layout, widget);
    notifyListeners();
  }

  void removeWidget(String id) {
    _layout = _engine.removeWidget(_layout, id);
    notifyListeners();
  }

  /// Replace an existing widget's config in-place (identified by [newConfig.id]).
  ///
  /// Use this to update app-defined [WidgetConfig.data] without touching the
  /// widget's grid position.
  void updateWidget(WidgetConfig newConfig) {
    final idx = _layout.indexWhere((e) => e.id == newConfig.id);
    if (idx == -1) return;
    _layout = List.of(_layout)..[idx] = newConfig;
    notifyListeners();
  }
}
