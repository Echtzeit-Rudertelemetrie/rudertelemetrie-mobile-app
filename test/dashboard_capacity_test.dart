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

  test('the dashboard is always exactly one viewport tall', () {
    final rows = model.rows;

    for (var i = 0; i < 20; i++) {
      model.addWidget(_tile('w$i'));
    }

    expect(model.rows, rows);
  });

  test('the viewport fills to capacity without overlapping tiles', () {
    final capacity = model.cols * model.rows;
    for (var i = 0; i < capacity; i++) {
      expect(model.addWidget(_tile('w$i')), isTrue);
    }

    expect(model.layout.length, capacity);
    expect(_anyOverlap(model.layout), isFalse);
    expect(model.layout.every((w) => w.y + w.h <= model.rows), isTrue);
  });

  test('refuses a tile once the viewport is full', () {
    final capacity = model.cols * model.rows;
    for (var i = 0; i < capacity; i++) {
      model.addWidget(_tile('w$i'));
    }

    expect(model.addWidget(_tile('one_too_many')), isFalse);
    expect(model.layout.any((w) => w.id == 'one_too_many'), isFalse);
  });

  test(
    'tall tiles land without overlapping, and stop when they no longer fit',
    () {
      final w = model.cols ~/ 2;
      final h = (model.rows / 2.5).floor();

      var placed = 0;
      for (var i = 0; i < 20; i++) {
        if (model.addWidget(_tile('w$i', w: w, h: h))) placed++;
      }

      expect(placed, 4);
      expect(_anyOverlap(model.layout), isFalse);
      expect(model.layout.every((w) => w.y + w.h <= model.rows), isTrue);
    },
  );

  test('a tile taller than the viewport is refused outright', () {
    expect(model.addWidget(_tile('giant', h: model.rows + 1)), isFalse);
    expect(model.layout, isEmpty);
  });
}
