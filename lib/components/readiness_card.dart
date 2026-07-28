import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/status_card.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_model.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/screens/connected_devices_screen.dart';
import 'package:rudertelemetrie_mobile_app/screens/rig_setup_screen.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oarlocks.dart';

/// What Home says before the user pushes off: whether the boat is wired up,
/// rigged, and pointed at the dashboard they meant to use.
///
/// Every state here was previously discoverable only by opening the screen it
/// belongs to — an unrigged oarlock announced itself for the first time as a
/// banner on the dashboard, once already on the water.
class ReadinessCard extends StatelessWidget {
  const ReadinessCard({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<DataSourceProviderModel>().registry;
    final config = context.watch<BoatConfig>();
    final preset = context.watch<DashboardModel>().activePreset?.name;

    final connected = connectedOarlockKeys(registry);
    final needingRig = oarlocksNeedingRig(registry, config);

    return StatusCard(
      title: 'Ready to row',
      rows: [
        StatusRow(
          title: 'Oarlocks',
          value: connected.isEmpty
              ? 'None connected'
              : '${connected.length} connected',
          tone: connected.isEmpty ? StatusTone.warning : StatusTone.ok,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConnectedDevicesScreen()),
          ),
        ),
        StatusRow(
          title: 'Rig',
          value: _rigValue(connected.length, needingRig.length),
          tone: _rigTone(connected.length, needingRig.length),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RigSetupScreen()),
          ),
        ),
        // Informational only: the Open Dashboard button sits directly below,
        // and two controls doing the same thing is one too many.
        StatusRow(
          title: 'Dashboard',
          value: preset ?? 'Loading…',
          tone: StatusTone.neutral,
        ),
      ],
    );
  }

  String _rigValue(int connected, int needingRig) {
    if (connected == 0) return 'No oarlocks';
    if (needingRig == 0) return 'Complete';
    return 'Needs setup';
  }

  StatusTone _rigTone(int connected, int needingRig) {
    if (connected == 0) return StatusTone.neutral;
    return needingRig == 0 ? StatusTone.ok : StatusTone.warning;
  }
}
