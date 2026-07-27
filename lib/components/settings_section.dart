import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:rudertelemetrie_mobile_app/screens/boat_setup_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/connected_devices_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/history_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/recording_settings_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/rig_setup_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/stroke_settings_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/speed_settings_screen.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) => FTileGroup(
    label: const Text('Settings'),
    children: [
      .tile(
        prefix: const Icon(FIcons.bluetooth),
        title: const Text('Oarlocks'),
        suffix: const Icon(FIcons.chevronRight),
        onPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConnectedDevicesScreen()),
        ),
      ),
      .tile(
        prefix: const Icon(FIcons.wrench),
        title: const Text('Rig Setup'),
        suffix: const Icon(FIcons.chevronRight),
        onPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RigSetupScreen()),
        ),
      ),
      .tile(
        prefix: const Icon(FIcons.rows3),
        title: const Text('Boat Setup'),
        suffix: const Icon(FIcons.chevronRight),
        onPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BoatSetupScreen()),
        ),
      ),
      .tile(
        prefix: const Icon(FIcons.activity),
        title: const Text('Stroke Detection'),
        suffix: const Icon(FIcons.chevronRight),
        onPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StrokeSettingsScreen()),
        ),
      ),
      .tile(
        prefix: const Icon(FIcons.circleDot),
        title: const Text('Recording'),
        suffix: const Icon(FIcons.chevronRight),
        onPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecordingSettingsScreen()),
        ),
      ),
      .tile(
        prefix: const Icon(Icons.speed),
        title: const Text('Geschwindigkeitseinheit'),
        subtitle: const Text('km/h, m/s oder /500 m'),
        suffix: const Icon(FIcons.chevronRight),
        onPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SpeedSettingsScreen()),
        ),
      ),
      .tile(
        prefix: const Icon(FIcons.history),
        title: const Text('History'),
        suffix: const Icon(FIcons.chevronRight),
        onPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        ),
      ),
    ],
  );
}
