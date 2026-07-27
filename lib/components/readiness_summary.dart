import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_model.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/screens/boat_setup_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/connected_devices_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/rig_setup_screen.dart';
import 'package:rudertelemetrie_mobile_app/services/data_processing/data_source_registry.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oarlocks.dart';

/// What the user needs to know before carrying the phone to the boat: are the
/// oarlocks on, is the rig set, is GPS producing fixes, which dashboard is up.
/// Every row taps through to the screen that fixes it.
class ReadinessSummary extends StatelessWidget {
  const ReadinessSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<DataSourceProviderModel>().registry;
    final config = context.watch<BoatConfig>();
    final dashboard = context.watch<DashboardModel>();

    final oarlocks = connectedOarlockKeys(registry);
    final needingRig = oarlocksNeedingRig(registry, config);

    return FTileGroup(
      label: const Text('Readiness'),
      children: [
        _row(
          context,
          icon: FIcons.bluetooth,
          title: 'Oarlocks',
          detail: oarlocks.isEmpty
              ? 'None connected'
              : '${oarlocks.length} connected',
          ready: oarlocks.isNotEmpty,
          destination: const ConnectedDevicesScreen(),
        ),
        _row(
          context,
          icon: FIcons.wrench,
          title: 'Rig',
          detail: oarlocks.isEmpty
              ? 'Nothing to configure yet'
              : needingRig.isEmpty
              ? 'Configured'
              : '${needingRig.length} still to set up',
          ready: oarlocks.isNotEmpty && needingRig.isEmpty,
          destination: const RigSetupScreen(),
        ),
        _row(
          context,
          icon: FIcons.mapPin,
          title: 'GPS',
          detail: _hasGps(registry) ? 'Receiving fixes' : 'No fix',
          ready: _hasGps(registry),
          destination: const ConnectedDevicesScreen(),
        ),
        _row(
          context,
          icon: FIcons.layoutGrid,
          title: 'Dashboard',
          detail: dashboard.activePreset?.name ?? 'None',
          ready: (dashboard.activePreset?.layout.isNotEmpty) ?? false,
          destination: const BoatSetupScreen(),
        ),
      ],
    );
  }

  bool _hasGps(DataSourceRegistry registry) =>
      registry.all.any((s) => s.name.startsWith('Latitude'));

  FTileMixin _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
    required bool ready,
    required Widget destination,
  }) => FTile(
    prefix: Icon(icon, color: ready ? Colors.greenAccent : Colors.amber),
    title: Text(title),
    subtitle: Text(detail),
    suffix: const Icon(FIcons.chevronRight),
    onPress: () =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
  );
}
