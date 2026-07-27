import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_model.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_config.dart';

WidgetConfig _tile(String id, {int w = 1, int h = 1}) =>
    WidgetConfig(id: id, x: 0, y: 0, w: w, h: h);

bool _anyOverlap(List<WidgetConfig> layout) {
  for (var i = 0; i < layout.length; i++) {
    for (var j = i + 1; j < layout.length; j++) {
      final a = layout[i];
      final b = layout[j];
      if (a.x < b.x + b.w &&
          a.x + a.w > b.x &&
          a.y < b.y + b.h &&
          a.y + a.h > b.y) {
        return true;
      }
    }
  }
  return false;
}

void main() {
  late DashboardModel model;

  setUp(() => model = DashboardModel());

  test('an empty dashboard is one viewport tall', () {
    expect(model.rows, DashboardModel.viewportRows);
  });

  test('the grid grows past the viewport instead of overlapping tiles', () {
    final capacity = model.cols * DashboardModel.viewportRows;
    for (var i = 0; i < capacity + 8; i++) {
      expect(model.addWidget(_tile('w$i')), isTrue);
    }

    expect(model.layout.length, capacity + 8);
    expect(model.rows, greaterThan(DashboardModel.viewportRows));
    expect(_anyOverlap(model.layout), isFalse);
  });

  test('tall tiles also land without overlapping', () {
    for (var i = 0; i < 20; i++) {
      expect(model.addWidget(_tile('w$i', w: 2, h: 3)), isTrue);
    }
    expect(_anyOverlap(model.layout), isFalse);
  });

  test('refuses a tile once the row ceiling is reached', () {
    var added = 0;
    while (model.addWidget(_tile('w$added'))) {
      added++;
      if (added > DashboardModel.maxRows * model.cols) break;
    }

    expect(model.rows, lessThanOrEqualTo(DashboardModel.maxRows));
    expect(_anyOverlap(model.layout), isFalse);
    expect(model.addWidget(_tile('one_too_many')), isFalse);
    expect(model.layout.any((w) => w.id == 'one_too_many'), isFalse);
  });
}
