import 'package:flutter/cupertino.dart';
import 'package:forui/forui.dart';
import 'package:rudertelemetrie_mobile_app/components/settings/frequency_slider.dart';

class SimulationSettingsScreen extends StatefulWidget {
  const SimulationSettingsScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SimulationSettingsScreenState();
}

class _SimulationSettingsScreenState extends State<SimulationSettingsScreen> {
  int frequency = 0;

  @override
  Widget build(BuildContext context) => FScaffold(
    header: FHeader.nested(
      title: const Text("Simulation"),
      prefixes: [
        FHeaderAction(
          icon: const Icon(FIcons.arrowLeft),
          onPress: () => Navigator.pop(context),
        ),
      ],
    ),
    child: Column(spacing: 10, children: [
      FrequencySlider()
    ]),
  );
}