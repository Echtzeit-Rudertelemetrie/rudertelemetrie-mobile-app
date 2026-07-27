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
                padding: EdgeInsets.zero,
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

/// One oarlock's rig. The fields hold a draft: a rig is only written once both
/// lengths are present and the geometry is usable, so a half-filled form never
/// stores a scull length the user never typed.
class _OarlockRig extends StatefulWidget {
  final String oarlockKey;
  final RigConfig? rig;

  const _OarlockRig({super.key, required this.oarlockKey, required this.rig});

  @override
  State<_OarlockRig> createState() => _OarlockRigState();
}

class _OarlockRigState extends State<_OarlockRig> {
  double? _innerLever;
  double? _scullLength;

  @override
  void initState() {
    super.initState();
    _adoptRig();
  }

  @override
  void didUpdateWidget(_OarlockRig old) {
    super.didUpdateWidget(old);
    if (widget.rig == old.rig) return;
    setState(_adoptRig);
  }

  void _adoptRig() {
    _innerLever = widget.rig?.innerLever;
    _scullLength = widget.rig?.scullLength;
  }

  RigConfig? get _draft {
    final innerLever = _innerLever;
    final scullLength = _scullLength;
    if (innerLever == null || scullLength == null) return null;
    final rig = RigConfig(innerLever: innerLever, scullLength: scullLength);
    return rig.isValid ? rig : null;
  }

  void _setInnerLever(double value) => _commit(() => _innerLever = value);

  void _setScullLength(double value) => _commit(() => _scullLength = value);

  void _applyDefaults() => _commit(() {
    _innerLever = BoatConfig.defaultRig.innerLever;
    _scullLength = BoatConfig.defaultRig.scullLength;
  });

  void _commit(VoidCallback edit) {
    setState(edit);
    final rig = _draft;
    if (rig == null) return;
    context.read<BoatConfig>().setRig(widget.oarlockKey, rig);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.oarlockKey,
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
                key: ValueKey('${widget.oarlockKey}.lin'),
                label: 'Inner lever l_in',
                unit: 'm',
                value: _innerLever,
                placeholder: '${BoatConfig.defaultRig.innerLever}',
                validate: _validateInnerLever,
                onCommitted: _setInnerLever,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NumberInputField(
                key: ValueKey('${widget.oarlockKey}.L'),
                label: 'Scull length L',
                unit: 'm',
                value: _scullLength,
                placeholder: '${BoatConfig.defaultRig.scullLength}',
                validate: _validateScullLength,
                onCommitted: _setScullLength,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _status(),
        if (widget.rig?.isValid != true) ...[
          const SizedBox(height: 8),
          FButton(
            variant: FButtonVariant.outline,
            onPress: _applyDefaults,
            child: Text(
              'Use example rig '
              '(${BoatConfig.defaultRig.innerLever} / '
              '${BoatConfig.defaultRig.scullLength} m)',
            ),
          ),
        ],
      ],
    ),
  );

  /// The screen has no save button — a valid pair is written as soon as it is
  /// entered — so this line is the only feedback that it landed.
  Widget _status() {
    final saved = widget.rig;
    final (text, color) = saved != null && saved.isValid
        ? (
            'Saved · outer lever l_out = '
                '${saved.outerLever.toStringAsFixed(2)} m',
            Colors.greenAccent,
          )
        : (
            'Not set — enter l_in and L to enable force and power for this '
                'oarlock.',
            Colors.amber,
          );
    return Text(text, style: TextStyle(color: color, fontSize: 12));
  }

  /// The outer lever `L − l_in` drives every force and power source; a
  /// non-positive one makes the rig invalid and unregisters them all, so it is
  /// rejected here rather than written and silently propagated.
  String? _validateInnerLever(double value) {
    if (value <= 0) return 'Must be greater than 0';
    final scullLength = _scullLength;
    if (scullLength != null && value >= scullLength) {
      return 'Must be less than L ($scullLength m)';
    }
    return null;
  }

  String? _validateScullLength(double value) {
    if (value <= 0) return 'Must be greater than 0';
    final innerLever = _innerLever;
    if (innerLever != null && value <= innerLever) {
      return 'Must exceed l_in ($innerLever m)';
    }
    return null;
  }
}
