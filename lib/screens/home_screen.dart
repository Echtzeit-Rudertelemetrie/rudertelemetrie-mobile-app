import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:rudertelemetrie_mobile_app/components/settings_section.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  void handleStartPress() {

  }

  @override
  Widget build(BuildContext _) => FScaffold(
    header: FHeader(
      title: const Text("Home"),
    ),
    child: Column(
      spacing: 10,
      children: [
        SettingsSection(),
        FButton(
            onPress: handleStartPress,
            child: const Text("Start")
        )
      ],
    ),
  );
}
