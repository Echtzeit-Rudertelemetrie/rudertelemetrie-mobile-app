import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/models/speed_settings_model.dart';

class SpeedSettingsScreen extends StatelessWidget {
  const SpeedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SpeedSettingsModel>();

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Geschwindigkeit'),
        prefixes: [
          FHeaderAction(
            icon: const Icon(FIcons.arrowLeft),
            onPress: () => Navigator.pop(context),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            type: MaterialType.transparency,
            child: RadioGroup<SpeedDisplayUnit>(
              groupValue: settings.displayUnit,
              onChanged: (value) {
                if (value != null) settings.setDisplayUnit(value);
              },
              child: const Column(
                children: [
                  RadioListTile(
                    value: SpeedDisplayUnit.kmh,
                    title: Text('Kilometer pro Stunde'),
                    subtitle: Text('km/h (Standard)'),
                  ),
                  RadioListTile(
                    value: SpeedDisplayUnit.mps,
                    title: Text('Meter pro Sekunde'),
                    subtitle: Text('m/s'),
                  ),
                  RadioListTile(
                    value: SpeedDisplayUnit.pace500m,
                    title: Text('Pace'),
                    subtitle: Text('min/500 m'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
