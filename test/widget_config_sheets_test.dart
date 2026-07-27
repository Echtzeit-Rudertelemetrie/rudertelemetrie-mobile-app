import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/add_widget_sheet.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_model.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/stream_selector_sheet.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/tile_kind.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_config.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/source_requirement.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';

void main() {
  late DashboardModel dashboard;
  late DataSourceProviderModel sources;

  setUp(() {
    dashboard = DashboardModel();
    sources = DataSourceProviderModel();
    // One of each kind the pickers filter on: a plain sample stream, an oar
    // angle, and a per-stroke value.
    sources.registry.register(
      PushDataSource(name: 'Force (EE01)', unit: Unit.N, group: 'Oarlock EE01'),
    );
    sources.registry.register(
      PushDataSource(
        name: 'Angle (EE01)',
        unit: Unit.deg,
        group: 'Oarlock EE01',
      ),
    );
    sources.registry.register(
      PushDataSource(
        name: 'Stroke Rate',
        unit: Unit.spm,
        group: 'Stroke',
        perStroke: true,
      ),
    );
  });

  /// The sheet body scrolls, so a field below the fold has to be brought into
  /// view before it can be tapped.
  Future<void> tapField(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  Widget host(Widget sheet) {
    final visualizers = VisualizerProviderModel();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: dashboard),
        ChangeNotifierProvider.value(value: sources),
        ChangeNotifierProvider.value(value: visualizers),
        ChangeNotifierProvider(create: (_) => AppNotifications()),
        ChangeNotifierProvider(
          create: (_) => RecordingSession(registry: sources.registry),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: sheet)),
    );
  }

  WidgetConfig storedWidget(String type) => WidgetConfig(
    id: 'w1',
    x: 0,
    y: 0,
    w: 1,
    h: 1,
    data: {
      'type': type,
      'visualizerKey': 'Time Window',
      'sourceKeys': ['Force (EE01)'],
      'params': <String, double>{},
    },
  );

  group('AddWidgetSheet step one', () {
    testWidgets('offers every tile kind, each with what it shows', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));

      for (final kind in TileKind.values) {
        expect(find.text(kind.label), findsOneWidget, reason: kind.label);
        expect(
          find.text(kind.description),
          findsOneWidget,
          reason: kind.description,
        );
      }
    });

    testWidgets('places an instrument straight away, with no second step', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Boat');

      expect(dashboard.layout.single.data['type'], 'schematic');
      expect(dashboard.layout.single.data['sourceKeys'], isEmpty);
    });

    testWidgets('a data tile leads on to its configuration', (tester) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Chart');

      expect(find.text('Visualizer'), findsOneWidget);
      expect(find.text('Add Chart'), findsOneWidget);
      expect(dashboard.layout, isEmpty);
    });

    testWidgets('the gauge asks for an oar angle and nothing else', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Gauge');

      expect(find.text('Visualizer'), findsNothing);
      expect(find.text('Reduction'), findsNothing);
      expect(find.text('Angle'), findsOneWidget);
      // A dial drawn around catch and finish has nothing to do with newtons.
      expect(find.text('Force'), findsNothing);
      expect(find.text('Stroke Rate'), findsNothing);
    });

    testWidgets('going back returns to the kind list, keeping nothing', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Chart');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Add Widget'), findsOneWidget);
      expect(find.text(TileKind.track.description), findsOneWidget);
      expect(dashboard.layout, isEmpty);
    });
  });

  group('AddWidgetSheet step two', () {
    testWidgets('names a source by its metric, not its device suffix', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Chart');

      expect(find.text('Force'), findsOneWidget);
      expect(find.text('Force (EE01)'), findsNothing);
      expect(
        find.text('Force at the oarlock pin, as the sensor reads it.'),
        findsOneWidget,
      );
    });

    testWidgets('adds the tile at a single cell', (tester) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Chart');
      await tapField(tester, 'Force');
      await tapField(tester, 'Add Chart');

      expect(dashboard.layout.single.w, 1);
      expect(dashboard.layout.single.h, 1);
      expect(dashboard.layout.single.data['type'], 'chart');
      expect(dashboard.layout.single.data['sourceKeys'], ['Force (EE01)']);
    });

    testWidgets('a gauge stores the picked source and no visualizer', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Gauge');
      await tapField(tester, 'Angle');
      await tapField(tester, 'Add Gauge');

      expect(dashboard.layout.single.data['type'], 'gauge');
      expect(dashboard.layout.single.data['sourceKeys'], ['Angle (EE01)']);
      expect(
        dashboard.layout.single.data.containsKey('visualizerKey'),
        isFalse,
      );
    });
  });

  group('only what makes sense is offered', () {
    testWidgets('a value tile asks no visualizer question at all', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Value');

      // Only Time Window survives the filter, so there is nothing to choose —
      // and its window is invisible in a tile showing one number.
      expect(find.text('Visualizer'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Time window'), findsNothing);
      expect(find.text('Data source'), findsOneWidget);
      expect(find.text('Reduction'), findsOneWidget);
    });

    testWidgets('a chart still offers the full range of visualizers', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Chart');

      expect(find.text('Visualizer'), findsOneWidget);
      for (final name in [
        'Time Window',
        'Since Threshold',
        'X vs Y (Window)',
        'Per-Stroke Bars',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
    });

    testWidgets('a bar tile offers only per-stroke sources', (tester) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Bar');

      // Per-Stroke Bars is the only shape a bar draws, and indexing by stroke
      // number is meaningless on a 100 Hz stream.
      expect(find.text('Visualizer'), findsNothing);
      expect(find.text('Stroke Rate'), findsOneWidget);
      expect(find.text('Force'), findsNothing);
      expect(find.text('Angle'), findsNothing);
    });

    testWidgets('says why a list is empty rather than showing nothing', (
      tester,
    ) async {
      sources.registry.unregister('Stroke Rate');
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Bar');

      expect(
        find.text(SourceRequirement.perStroke.emptyMessage),
        findsOneWidget,
      );
    });
  });

  group('StreamSelectorSheet', () {
    testWidgets('offers the same options as the add sheet', (tester) async {
      await tester.pumpWidget(
        host(StreamSelectorSheet(config: storedWidget('chart'))),
      );

      for (final label in ['Chart', 'Value', 'Bar']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Reduction'), findsOneWidget);
      expect(find.text('Visualizer'), findsOneWidget);
    });

    testWidgets('applies a reduction to the stored widget', (tester) async {
      dashboard.addWidget(storedWidget('chart'));
      await tester.pumpWidget(
        host(StreamSelectorSheet(config: storedWidget('chart'))),
      );

      await tapField(tester, 'Peak since start');
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(dashboard.layout.single.data['sourceKeys'], ['Peak Force (EE01)']);
    });

    testWidgets('switches a chart to a bar tile', (tester) async {
      dashboard.addWidget(storedWidget('chart'));
      await tester.pumpWidget(
        host(StreamSelectorSheet(config: storedWidget('chart'))),
      );

      await tester.tap(find.text('Bar'));
      await tester.pump();
      // Time Window cannot feed a bar tile, so the switch re-homes the
      // visualizer — which drops a source the new one cannot read.
      await tapField(tester, 'Stroke Rate');
      await tapField(tester, 'Apply');

      expect(dashboard.layout.single.data['type'], 'bar');
      expect(dashboard.layout.single.data['visualizerKey'], 'Per-Stroke Bars');
      expect(dashboard.layout.single.data['sourceKeys'], ['Stroke Rate']);
    });
  });
}
