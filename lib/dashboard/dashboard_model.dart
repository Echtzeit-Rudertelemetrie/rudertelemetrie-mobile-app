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

  /// Replace a widget's [type] and/or [streamKey] in-place.
  void updateWidget(String id, {required String type, required String? streamKey}) {
    final idx = _layout.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final old = _layout[idx];
    final updated = WidgetConfig(
      id: old.id,
      x: old.x,
      y: old.y,
      w: old.w,
      h: old.h,
      type: type,
      streamKey: streamKey,
    );
    _layout = List.of(_layout)..[idx] = updated;
    notifyListeners();
  }
}
