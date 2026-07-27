import 'package:flutter/cupertino.dart';
import 'package:forui/forui.dart';
import 'package:rudertelemetrie_mobile_app/components/settings/connected_devices/connected_devices_settings.dart';

class ConnectedDevicesScreen extends StatelessWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) => FScaffold(
    header: FHeader.nested(
      title: const Text('Oarlocks'),
      prefixes: [
        FHeaderAction(
          icon: const Icon(FIcons.arrowLeft),
          onPress: () => Navigator.pop(context),
        ),
      ],
    ),
    child: Column(spacing: 10, children: [ConnectedDevicesSettings()]),
  );
}
