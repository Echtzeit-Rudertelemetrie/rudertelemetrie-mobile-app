import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/screens/stroke_settings_screen.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_settings.dart';

void main() {
  // Regression: the settings screens use Material widgets (TextField, Dropdown)
  // inside Forui's FScaffold, which provides no Material ancestor. The screen
  // bodies wrap in a transparent Material so those widgets build.
  testWidgets(
    'StrokeSettingsScreen renders its Material fields without error',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<StrokeSettings>(
          create: (_) => StrokeSettings(),
          child: MaterialApp(
            builder: (_, child) =>
                FTheme(data: FThemes.neutral.dark.desktop, child: child!),
            home: const StrokeSettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byType(TextField),
        findsWidgets,
      ); // absolute mode fields present
    },
  );

  testWidgets('rejects a finish force at or above the catch force', (
    tester,
  ) async {
    final settings = StrokeSettings();
    await tester.pumpWidget(_screen(settings));
    await tester.pump();

    await tester.enterText(find.byKey(const ValueKey('fOff')), '60');
    await tester.pump();

    expect(find.textContaining('Must be below F_on'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(settings.fOff, 20); // never committed
  });

  testWidgets('commits a valid value once, after the debounce', (tester) async {
    final settings = StrokeSettings();
    var notifications = 0;
    settings.addListener(() => notifications++);
    await tester.pumpWidget(_screen(settings));
    await tester.pump();

    for (final text in ['2', '25', '25.', '25.5']) {
      await tester.enterText(find.byKey(const ValueKey('fOff')), text);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(notifications, 0); // still debouncing

    await tester.pump(const Duration(milliseconds: 500));
    expect(settings.fOff, 25.5);
    expect(notifications, 1);
  });

  testWidgets('follows a value that changes underneath it', (tester) async {
    final settings = StrokeSettings();
    await tester.pumpWidget(_screen(settings));
    await tester.pump();

    settings.setAbsoluteThresholds(fOff: 33);
    await tester.pump();

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('fOff')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '33');
  });
}

Widget _screen(StrokeSettings settings) =>
    ChangeNotifierProvider<StrokeSettings>.value(
      value: settings,
      child: MaterialApp(
        builder: (_, child) =>
            FTheme(data: FThemes.neutral.dark.desktop, child: child!),
        home: const StrokeSettingsScreen(),
      ),
    );
