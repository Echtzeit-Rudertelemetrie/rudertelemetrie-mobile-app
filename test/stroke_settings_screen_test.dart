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
  testWidgets('StrokeSettingsScreen renders its Material fields without error',
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
    expect(find.byType(TextField), findsWidgets); // absolute mode fields present
  });
}
