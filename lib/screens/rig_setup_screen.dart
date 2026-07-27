import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/settings/number_input_field.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oarlocks.dart';

/// Setup → Rig (boat-rig-config Part A): per-oarlock inner lever `l_in` and
/// scull length `L`. These are mandatory for every force/power source.
class RigSetupScreen extends StatelessWidget {
  const RigSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<DataSourceProviderModel>().registry;
    final config = context.watch<BoatConfig>();
    final keys = {
      ...connectedOarlockKeys(registry),
      ...config.oarlockKeys,
    }.toList()..sort();

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Rig Setup'),
        prefixes: [
          FHeaderAction(
            icon: const Icon(FIcons.arrowLeft),
            onPress: () => Navigator.pop(context),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: keys.isEmpty
            ? const _EmptyHint()
            : ListView(
                children: [
                  for (final key in keys)
                    _OarlockRig(
                      key: ValueKey(key),
                      oarlockKey: key,
                      rig: config.rigFor(key),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Connect an oarlock to configure its rig.',
        style: TextStyle(color: Colors.white54),
      ),
    ),
  );
}

class _OarlockRig extends StatelessWidget {
  final String oarlockKey;
  final RigConfig? rig;

  const _OarlockRig({super.key, required this.oarlockKey, required this.rig});

  double get innerLever => rig?.innerLever ?? BoatConfig.defaultRig.innerLever;
  double get scullLength =>
      rig?.scullLength ?? BoatConfig.defaultRig.scullLength;

  void _update(
    BuildContext context, {
    double? innerLever,
    double? scullLength,
  }) {
    final current = rig ?? BoatConfig.defaultRig;
    context.read<BoatConfig>().setRig(
      oarlockKey,
      RigConfig(
        innerLever: innerLever ?? current.innerLever,
        scullLength: scullLength ?? current.scullLength,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          oarlockKey,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: NumberInputField(
                key: ValueKey('$oarlockKey.lin'),
                label: 'Inner lever l_in',
                unit: 'm',
                value: innerLever,
                validate: (v) => _validateInnerLever(v, scullLength),
                onCommitted: (v) => _update(context, innerLever: v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NumberInputField(
                key: ValueKey('$oarlockKey.L'),
                label: 'Scull length L',
                unit: 'm',
                value: scullLength,
                validate: (v) => _validateScullLength(v, innerLever),
                onCommitted: (v) => _update(context, scullLength: v),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  /// The outer lever `L − l_in` drives every force and power source; a
  /// non-positive one makes the rig invalid and unregisters them all, so it is
  /// rejected here rather than written and silently propagated.
  static String? _validateInnerLever(double value, double scullLength) {
    if (value <= 0) return 'Must be greater than 0';
    if (value >= scullLength) return 'Must be less than L ($scullLength m)';
    return null;
  }

  static String? _validateScullLength(double value, double innerLever) {
    if (value <= 0) return 'Must be greater than 0';
    if (value <= innerLever) return 'Must exceed l_in ($innerLever m)';
    return null;
  }
}
