import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:rudertelemetrie_mobile_app/screens/connected_devices_screen.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) => FTileGroup(
    label: const Text('Settings'),
    children: [
      .tile(
        prefix: const Icon(FIcons.slidersHorizontal),
        title: const Text('Connected Devices'),
        suffix: const Icon(FIcons.chevronRight),
        onPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConnectedDevicesScreen()),
        ),
      ),
    ],
  );
}
