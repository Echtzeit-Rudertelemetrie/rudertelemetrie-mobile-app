import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/sine_wave_chart.dart';
import 'package:rudertelemetrie_mobile_app/models/simulation_settings_model.dart';
import 'package:rudertelemetrie_mobile_app/services/signal_generator_service.dart';

class LiveDataScreen extends StatefulWidget {
  const LiveDataScreen({super.key});

  @override
  State<LiveDataScreen> createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  late final SignalGeneratorService _service;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final frequency = context.read<SimulationSettingsModel>().frequency;
    _service = SignalGeneratorService(frequency: frequency);
  }

  @override
  void dispose() {
    _service.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FScaffold(
    header: FHeader.nested(
      title: const Text('Live Data'),
      prefixes: [
        FHeaderAction(
          icon: const Icon(FIcons.arrowLeft),
          onPress: () => Navigator.pop(context),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SineWaveChart(signal: _service.signal),
    ),
  );
}
