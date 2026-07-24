import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
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
    final keys = {...connectedOarlockKeys(registry), ...config.oarlockKeys}.toList()
      ..sort();

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

  void _update(BuildContext context, {double? innerLever, double? scullLength}) {
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
          children: [
            Expanded(
              child: _RigField(
                key: ValueKey('$oarlockKey.lin'),
                label: 'Inner lever l_in',
                value: rig?.innerLever ?? BoatConfig.defaultRig.innerLever,
                onChanged: (v) => _update(context, innerLever: v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RigField(
                key: ValueKey('$oarlockKey.L'),
                label: 'Scull length L',
                value: rig?.scullLength ?? BoatConfig.defaultRig.scullLength,
                onChanged: (v) => _update(context, scullLength: v),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RigField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _RigField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_RigField> createState() => _RigFieldState();
}

class _RigFieldState extends State<_RigField> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));

  static String _format(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : '$v';

  void _handleChanged(String raw) {
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed != null && parsed > 0) widget.onChanged(parsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: const Color(0xFFF45866),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white10,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFF45866)),
                ),
              ),
              onChanged: _handleChanged,
            ),
          ),
          const SizedBox(width: 6),
          const Text('m', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    ],
  );
}
