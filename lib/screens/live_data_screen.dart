import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/live_value_display.dart';
import 'package:rudertelemetrie_mobile_app/components/sine_wave_chart.dart';
import 'package:rudertelemetrie_mobile_app/models/simulation_settings_model.dart';
import 'package:rudertelemetrie_mobile_app/services/random_number_service.dart';
import 'package:rudertelemetrie_mobile_app/services/signal_generator_service.dart';

class LiveDataScreen extends StatefulWidget {
  const LiveDataScreen({super.key});

  @override
  State<LiveDataScreen> createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  late final SignalGeneratorService _sineService;
  late final SignalGeneratorService _sineService2;
  late final RandomNumberService _heartRateService;
  late final RandomNumberService _powerService;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final frequency = context.read<SimulationSettingsModel>().frequency;
    _sineService = SignalGeneratorService(frequency: frequency);
    _sineService2 = SignalGeneratorService(frequency: frequency * 2);
    _heartRateService = RandomNumberService(min: 60, max: 180);
    _powerService = RandomNumberService(min: 100, max: 400);
  }

  void _exitScreen() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _sineService.dispose();
    _sineService2.dispose();
    _heartRateService.dispose();
    _powerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (_, _) =>
        SystemChrome.setPreferredOrientations(DeviceOrientation.values),
    child: FScaffold(
      header: FHeader.nested(
        title: const Text('Live Data'),
        prefixes: [
          FHeaderAction(
            icon: const Icon(FIcons.arrowLeft),
            onPress: _exitScreen,
          ),
        ],
      ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SineWaveChart(signals: [_sineService.signal, _sineService2.signal]),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 140,
            child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              LiveValueDisplay(
                signal: _heartRateService.signal,
                label: 'Heart Rate',
                unit: ' bpm',
                decimalPlaces: 0,
              ),
              LiveValueDisplay(
                signal: _powerService.signal,
                label: 'Power',
                unit: ' W',
                decimalPlaces: 0,
              ),
            ],
          ),
          ),
        ],
      ),
    ),
  ));
}
