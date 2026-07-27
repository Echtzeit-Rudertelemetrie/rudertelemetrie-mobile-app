import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/add_widget_sheet.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_model.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/stream_selector_sheet.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_config.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/push_data_source.dart';
import 'package:rudertelemetrie_mobile_app/services/notifications/app_notifications.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';

void main() {
  late DashboardModel dashboard;
  late DataSourceProviderModel sources;

  setUp(() {
    dashboard = DashboardModel();
    sources = DataSourceProviderModel();
    sources.registry.register(
      PushDataSource(name: 'Force (EE01)', unit: Unit.N, group: 'Oarlock EE01'),
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

  group('AddWidgetSheet', () {
    testWidgets('offers every display type the dashboard can render', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));

      for (final label in ['Chart', 'Value', 'Bar', 'Gauge', 'Level', 'Map']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Reduction'), findsOneWidget);
    });

    testWidgets('adds the tile at a single cell', (tester) async {
      await tester.pumpWidget(host(const AddWidgetSheet()));
      await tapField(tester, 'Force (EE01)');
      await tester.tap(find.text('Chart'));
      await tester.pump();

      expect(dashboard.layout.single.w, 1);
      expect(dashboard.layout.single.h, 1);
      expect(dashboard.layout.single.data['sourceKeys'], ['Force (EE01)']);
    });
  });

  group('StreamSelectorSheet', () {
    testWidgets('offers the same options as the add sheet', (tester) async {
      await tester.pumpWidget(host(StreamSelectorSheet(config: storedWidget('chart'))));

      for (final label in ['Chart', 'Value', 'Bar']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Reduction'), findsOneWidget);
      expect(find.text('Visualizer'), findsOneWidget);
    });

    testWidgets('applies a reduction to the stored widget', (tester) async {
      dashboard.addWidget(storedWidget('chart'));
      await tester.pumpWidget(host(StreamSelectorSheet(config: storedWidget('chart'))));

      await tapField(tester, 'Peak since start');
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(dashboard.layout.single.data['sourceKeys'], [
        'Peak Force (EE01)',
      ]);
    });

    testWidgets('switches a chart to a bar tile', (tester) async {
      dashboard.addWidget(storedWidget('chart'));
      await tester.pumpWidget(host(StreamSelectorSheet(config: storedWidget('chart'))));

      await tester.tap(find.text('Bar'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(dashboard.layout.single.data['type'], 'bar');
    });
  });
}
