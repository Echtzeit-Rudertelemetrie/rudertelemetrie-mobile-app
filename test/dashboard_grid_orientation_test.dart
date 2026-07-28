import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_grid.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_grid_size.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_model.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_widget_tile.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_config.dart';

const _portrait = Size(400, 800);
const _landscape = Size(800, 400);

Widget _grid(DashboardModel model, Size size) => MediaQuery(
  data: MediaQueryData(size: size),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: ChangeNotifierProvider.value(
      value: model,
      child: DashboardGrid(widgetBuilder: (_, _) => const SizedBox()),
    ),
  ),
);

void main() {
  late DashboardModel model;

  setUp(() {
    model = DashboardModel();
    model.addWidget(const WidgetConfig(id: 'a', x: 0, y: 0, w: 1, h: 1));
  });

  testWidgets('a portrait grid keeps the portrait columns', (tester) async {
    await tester.pumpWidget(_grid(model, _portrait));
    await tester.pump();

    expect(model.cols, DashboardGridSize.portraitCols);
  });

  testWidgets('a landscape grid switches to the finer columns', (tester) async {
    await tester.pumpWidget(_grid(model, _landscape));
    await tester.pump();

    expect(model.cols, DashboardGridSize.landscapeCols);
    expect(model.layout.single.w, model.columnStep);
  });

  testWidgets('rotating back returns to the portrait columns', (tester) async {
    await tester.pumpWidget(_grid(model, _landscape));
    await tester.pump();

    await tester.pumpWidget(_grid(model, _portrait));
    await tester.pump();

    expect(model.cols, DashboardGridSize.portraitCols);
    expect(model.layout.single.w, 1);
  });

  testWidgets('a tile spans its columns of the landscape width', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(model, _landscape));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final tile = tester.getRect(find.byType(DashboardWidgetTile));
    final cell = _landscape.width / DashboardGridSize.landscapeCols;

    expect(tile.width, closeTo(cell * model.layout.single.w, 8));
  });
}
