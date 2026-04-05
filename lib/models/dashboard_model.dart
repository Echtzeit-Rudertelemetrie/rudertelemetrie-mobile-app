import 'package:flutter/foundation.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_layout_engine.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_config.dart';

class DashboardModel extends ChangeNotifier {
  static const int _cols = 4;
  static const int _rows = 8;

  final _engine = const DashboardLayoutEngine(cols: _cols, rows: _rows);

  List<WidgetConfig> _layout = [
    const WidgetConfig(id: 'w1', x: 0, y: 0, w: 2, h: 3, type: 'placeholder'),
    const WidgetConfig(id: 'w2', x: 2, y: 0, w: 2, h: 2, type: 'placeholder'),
    const WidgetConfig(id: 'w3', x: 2, y: 2, w: 2, h: 1, type: 'placeholder'),
  ];

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
}
