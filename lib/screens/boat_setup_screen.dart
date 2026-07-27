import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oarlocks.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Boat & crew setup (boat-rig-config Part B): boat class + per-oarlock seat
/// (1 = bow) and side assignment. Feeds the boat schematic.
class BoatSetupScreen extends StatelessWidget {
  const BoatSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<DataSourceProviderModel>().registry;
    final config = context.watch<BoatConfig>();
    final keys = {
      ...connectedOarlockKeys(registry),
      ...config.slots.keys,
    }.toList()..sort();

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Boat Setup'),
        prefixes: [
          FHeaderAction(
            icon: const Icon(FIcons.arrowLeft),
            onPress: () => Navigator.pop(context),
          ),
        ],
      ),
      child: ListView(
        children: [
          const Text(
            'Boat class',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in BoatClass.values)
                _Chip(
                  label: c.label,
                  selected: config.boatClass == c,
                  onTap: () => config.setBoatClass(c),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Oarlocks',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (keys.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Connect an oarlock to assign it.',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          for (final key in keys)
            _OarlockAssignment(
              oarlockKey: key,
              seats: config.boatClass.seats,
              slot: config.slotFor(key),
              conflicting: config.conflictingSlotKeys.contains(key),
              connected: connectedOarlockKeys(registry).contains(key),
            ),
        ],
      ),
    );
  }
}

class _OarlockAssignment extends StatelessWidget {
  final String oarlockKey;
  final int seats;
  final SeatSlot? slot;
  final bool conflicting;
  final bool connected;

  const _OarlockAssignment({
    required this.oarlockKey,
    required this.seats,
    required this.slot,
    required this.conflicting,
    required this.connected,
  });

  void _update(BuildContext context, {int? seat, OarSide? side}) {
    final current = slot ?? const SeatSlot(seat: 1, side: OarSide.both);
    context.read<BoatConfig>().assignSlot(
      oarlockKey,
      SeatSlot(seat: seat ?? current.seat, side: side ?? current.side),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context),
        const SizedBox(height: 6),
        // Wrap, not Row: an eight puts nine chips on the seat line, which
        // overflows any phone.
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Seat',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            for (var s = 1; s <= seats; s++)
              _Chip(
                label: '$s',
                selected: (slot?.seat ?? -1) == s,
                onTap: () => _update(context, seat: s),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final side in OarSide.values)
              _Chip(
                label: side.name,
                selected: slot?.side == side,
                onTap: () => _update(context, side: side),
              ),
          ],
        ),
        if (conflicting) ...[
          const SizedBox(height: 6),
          const Text(
            'Another oarlock already holds this seat and side.',
            style: TextStyle(
              color: Colors.amber,
              fontSize: AppTypeScale.caption,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _header(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          connected ? oarlockKey : '$oarlockKey (not connected)',
          style: TextStyle(
            color: connected ? Colors.white : Colors.white54,
            fontSize: 14,
          ),
        ),
      ),
      if (slot != null)
        _TextAction(
          label: 'Unassign',
          onTap: () => context.read<BoatConfig>().clearSlot(oarlockKey),
        ),
      if (!connected) ...[
        const SizedBox(width: 12),
        _TextAction(
          label: 'Remove',
          onTap: () => context.read<BoatConfig>().removeOarlock(oarlockKey),
        ),
      ],
    ],
  );
}

class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      constraints: const BoxConstraints(minHeight: kMinTapTarget),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(color: AppPalette.accent, fontSize: 12),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _accent = AppPalette.accent;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      // Wet hands on a moving boat: nothing interactive below kMinTapTarget.
      constraints: const BoxConstraints(
        minHeight: kMinTapTarget,
        minWidth: kMinTapTarget,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _accent.withAlpha(selected ? 40 : 0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? _accent : Colors.white24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? _accent : Colors.white70,
          fontSize: 12,
        ),
      ),
    ),
  );
}
