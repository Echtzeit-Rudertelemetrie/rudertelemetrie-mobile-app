import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/simulation_settings_provider.dart';
import 'package:rudertelemetrie_mobile_app/screens//home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [simulationSettingsProvider],
      child: const Application(),
    ),
  );
}

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    final base =
        const <TargetPlatform>{
          .android,
          .iOS,
          .fuchsia,
        }.contains(defaultTargetPlatform)
        ? FThemes.neutral.dark.touch
        : FThemes.neutral.dark.desktop;

    const background = Color(0xFF0c0e1d);
    final newColors = base.colors.copyWith(
      primary: const Color(0xFFF45866),
      primaryForeground: Colors.white,
      background: background,
    );

    final theme = base.copyWith(
      colors: newColors,
      scaffoldStyle: base.scaffoldStyle.copyWith(backgroundColor: background),
      buttonStyles: FButtonStyles.inherit(
        colors: newColors,
        typography: base.typography,
        style: base.style,
        touch: const <TargetPlatform>{.android, .iOS, .fuchsia}.contains(defaultTargetPlatform),
      ),
      tileGroupStyle: FTileGroupStyle.inherit(
        colors: newColors.copyWith(card: background),
        typography: base.typography,
        style: base.style,
      ),
      sliderStyles: FSliderStyles.inherit(
        colors: newColors.copyWith(secondary: Colors.white),
        typography: base.typography,
        style: base.style,
      ),
    );

    return MaterialApp(
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      theme: theme.toApproximateMaterialTheme(),
      builder: (_, child) => FTheme(
        data: theme,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
      home: const FScaffold(child: Home()),
    );
  }
}