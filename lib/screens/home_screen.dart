import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:rudertelemetrie_mobile_app/components/settings_section.dart';
import 'package:rudertelemetrie_mobile_app/screens/dashboard_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/live_data_screen.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) => FScaffold(
    header: FHeader(
      title: const Text("Home"),
    ),
    child: Column(
      spacing: 10,
      children: [
        SettingsSection(),
        FButton(
          onPress: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LiveDataScreen()),
          ),
          child: const Text("Start"),
        ),
        FButton(
          variant: .outline,
          onPress: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          ),
          child: const Text("Dashboard"),
        ),
      ],
    ),
  );
}
