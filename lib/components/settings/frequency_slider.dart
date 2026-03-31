import 'package:flutter/cupertino.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/models/simulation_settings_model.dart';
import 'package:rudertelemetrie_mobile_app/utils/slider_util.dart';

class FrequencySlider extends StatefulWidget {
  const FrequencySlider({super.key});

  @override
  State<FrequencySlider> createState() => _FrequencySliderState();
}

class _FrequencySliderState extends State<FrequencySlider> {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<SimulationSettingsModel>();

    return Column(
      children: [
        FSlider(
          control: FSliderControl.managedContinuous(
            initial: FSliderValue(max: toSlider(model.frequency, 1, 500)),
          ),
          label: Text('Frequency: ${model.frequency} Hz'),
          tooltipBuilder: (style, value) => Text(intFromSlider(value, 1, 500).round().toString()),
          onEnd: (value) {
            context.read<SimulationSettingsModel>().setFrequency(intFromSlider(value.max, 1, 500));
          },
        ),
      ],
    );
  }
}