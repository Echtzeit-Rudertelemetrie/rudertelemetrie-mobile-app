import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibrations.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oar_side_detection.dart';
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
    final detection = context.watch<OarSideDetection>();
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
        padding: EdgeInsets.zero,
        children: [
          const _SectionLabel('Boat class'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in BoatClass.values)
                _Chip(
                  label: c.label,
                  selected: config.boatClass == c,
                  pill: true,
                  onTap: () => config.setBoatClass(c),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Oarlocks'),
          if (keys.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Connect an oarlock to assign it.',
                style: TextStyle(color: AppPalette.disabledLabel),
              ),
            ),
          for (final key in keys)
            _OarlockAssignment(
              oarlockKey: key,
              seats: config.boatClass.seats,
              slot: config.slotFor(key),
              conflicting: config.conflictingSlotKeys.contains(key),
              connected: connectedOarlockKeys(registry).contains(key),
              detected: detection.estimateFor(key),
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

  /// What `OarSideDetection` makes of this oarlock's swing direction, if it has
  /// seen enough strokes to say. Shown even when it agrees with the assignment
  /// so the provenance of a side is never a mystery.
  final OarSideEstimate? detected;

  const _OarlockAssignment({
    required this.oarlockKey,
    required this.seats,
    required this.slot,
    required this.conflicting,
    required this.connected,
    required this.detected,
  });

  void _update(BuildContext context, {int? seat, OarSide? side}) {
    final current =
        slot ??
        const SeatSlot(
          seat: 1,
          side: OarSide.both,
          sideOrigin: SideOrigin.unset,
        );
    context.read<BoatConfig>().assignSlot(
      oarlockKey,
      SeatSlot(
        seat: seat ?? current.seat,
        side: side ?? current.side,
        // Only a tap on a side chip is a manual choice. Creating the slot by
        // picking a seat leaves the side open, so detection may still fill it.
        sideOrigin: side != null ? SideOrigin.manual : current.sideOrigin,
      ),
    );
  }

  /// Adopts the detected side while keeping it marked as detected, so it goes
  /// on tracking the sensor rather than freezing at today's reading.
  void _adoptDetected(BuildContext context, OarSide side) {
    final current = slot;
    if (current == null) return;
    context.read<BoatConfig>().assignSlot(
      oarlockKey,
      SeatSlot(
        seat: current.seat,
        side: side,
        sideOrigin: SideOrigin.detected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
    decoration: BoxDecoration(
      color: AppPalette.overlay,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      border: Border.all(color: AppPalette.surfaceBorder),
    ),
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
              style: TextStyle(
                color: AppPalette.faintLabel,
                fontSize: AppTypeScale.caption,
              ),
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
        ..._detection(context),
        if (conflicting) ...[
          const SizedBox(height: 6),
          const Text(
            'Another oarlock already holds this seat and side.',
            style: TextStyle(
              color: AppPalette.warning,
              fontSize: AppTypeScale.caption,
            ),
          ),
        ],
      ],
    ),
  );

  /// Says where the current side came from, and what the sensor thinks.
  ///
  /// A detected side is auto-applied only where nothing was chosen by hand, so
  /// this line is what makes that visible; when detection disagrees with a
  /// manual choice it offers the swap instead of taking it.
  List<Widget> _detection(BuildContext context) {
    final estimate = detected;
    final current = slot;

    if (estimate == null) {
      if (current?.sideOrigin != SideOrigin.detected) return const [];
      return [
        _note(
          'Side was detected automatically.',
          AppPalette.faintLabel,
        ),
      ];
    }

    final rate = estimate.medianRateDegPerSecond.round();
    final summary =
        'Detected ${estimate.side.name} '
        '(${estimate.agreeingStrokes} of ${estimate.consideredStrokes} '
        'strokes, $rate °/s)';

    if (current == null) {
      return [_note('$summary — pick a seat to apply it.', AppPalette.accent)];
    }
    if (current.sideOrigin != SideOrigin.manual) {
      return [_note('$summary — applied automatically.', AppPalette.ok)];
    }
    if (current.side == estimate.side) {
      return [_note('$summary — matches your setting.', AppPalette.ok)];
    }
    return [
      _note('$summary — you set ${current.side.name}.', AppPalette.warning),
      _TextAction(
        label: 'Use detected side',
        onTap: () => _adoptDetected(context, estimate.side),
      ),
    ];
  }

  Widget _note(String text, Color color) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: AppTypeScale.caption),
    ),
  );

  Widget _header(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          connected ? oarlockKey : '$oarlockKey (not connected)',
          style: TextStyle(
            color: connected ? AppPalette.label : AppPalette.faintLabel,
            fontSize: AppTypeScale.body,
            fontWeight: FontWeight.w600,
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
          onTap: () => forgetOarlock(
            oarlockKey,
            config: context.read<BoatConfig>(),
            calibrations: context.read<ForceCalibrations>(),
            sideDetection: context.read<OarSideDetection>(),
          ),
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
        style: const TextStyle(
          color: AppPalette.accent,
          fontSize: AppTypeScale.label,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppPalette.faintLabel,
      fontSize: AppTypeScale.caption,
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Fully rounded, for chips that name a thing rather than a slot. Seat and
  /// side chips stay square-ish so a row of them reads as a set of positions.
  final bool pill;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.pill = false,
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
      decoration: BoxDecoration(
        color: _accent.withAlpha(selected ? 40 : 0),
        borderRadius: BorderRadius.circular(
          pill ? kMinTapTarget / 2 : AppRadii.control,
        ),
        border: Border.all(
          color: selected ? _accent : AppPalette.outline,
          width: 1.5,
        ),
      ),
      // Centred by an [Align] that shrink-wraps, not by `Container.alignment`:
      // that one has no size factors, so it swells to the widest size the
      // parent allows. Inside a [Wrap] that is the full row, which puts every
      // chip on a line of its own.
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: pill ? 18 : 12,
            vertical: 6,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _accent : AppPalette.mutedLabel,
              fontSize: AppTypeScale.label,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    ),
  );
}
