import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/bluetooth_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/visualizer_provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/simulation_settings_provider.dart';
import 'package:rudertelemetrie_mobile_app/screens//home_screen.dart';
import 'package:rudertelemetrie_mobile_app/utils/startup_util.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        simulationSettingsProvider,
        dashboardProvider,
        dataSourceProvider,
        visualizerProvider,
        bluetoothProvider,
      ],
      child: const Application(),
    ),
  );
}

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    final (theme,) = startup(context);

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
