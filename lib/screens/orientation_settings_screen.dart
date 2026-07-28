import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/display/orientation_settings.dart';

/// Whether the app rotates with the device, or stays in the orientation the
/// crew picked before pushing off.
class OrientationSettingsScreen extends StatelessWidget {
  const OrientationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<OrientationSettings>();

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Screen Orientation'),
        prefixes: [
          FHeaderAction(
            icon: const Icon(FIcons.arrowLeft),
            onPress: () => Navigator.pop(context),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: RadioGroup<OrientationLock>(
          groupValue: settings.lock,
          onChanged: (value) {
            if (value != null) settings.setLock(value);
          },
          child: const Column(
            children: [
              RadioListTile(
                value: OrientationLock.auto,
                title: Text('Automatic'),
                subtitle: Text('Follows the device (default)'),
              ),
              RadioListTile(
                value: OrientationLock.portrait,
                title: Text('Portrait'),
                subtitle: Text('Locked upright'),
              ),
              RadioListTile(
                value: OrientationLock.landscape,
                title: Text('Landscape'),
                subtitle: Text('Locked sideways, either way up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
