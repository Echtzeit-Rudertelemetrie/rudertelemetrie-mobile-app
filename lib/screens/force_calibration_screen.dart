import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/components/settings/number_input_field.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration_session.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Setup → Calibrate force (force-calibration §2): the guided two-point
/// calibration of one oarlock's load cell.
///
/// Deliberately shows no raw counts. The operator's job is to hold still and
/// name the weight; a number they cannot interpret only invites them to.
class ForceCalibrationScreen extends StatefulWidget {
  final String oarlockKey;

  const ForceCalibrationScreen({super.key, required this.oarlockKey});

  @override
  State<ForceCalibrationScreen> createState() => _ForceCalibrationScreenState();
}

class _ForceCalibrationScreenState extends State<ForceCalibrationScreen> {
  ForceCalibrationSession? _session;

  @override
  void initState() {
    super.initState();
    // After the frame: begin() notifies, and a notify during build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _session = context.read<ForceCalibrationSession>()
        ..begin(widget.oarlockKey);
    });
  }

  /// Backstop for a disposal that is not a pop — a replaced route would
  /// otherwise leave zero tracking paused with nothing on screen saying so.
  /// Deferred because cancel() notifies, and notifying mid-unmount throws.
  @override
  void dispose() {
    final session = _session;
    if (session != null && session.isActive) {
      scheduleMicrotask(session.cancel);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ForceCalibrationSession>();

    return PopScope(
      onPopInvokedWithResult: (_, _) => session.cancel(),
      child: FScaffold(
        header: FHeader.nested(
          title: const Text('Calibrate Force'),
          prefixes: [
            FHeaderAction(
              icon: const Icon(FIcons.arrowLeft),
              onPress: () => Navigator.pop(context),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Text(
                widget.oarlockKey,
                style: const TextStyle(
                  color: AppPalette.label,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (session.isBlockedByRecording)
                const _Blocked()
              else
                _StepBody(session: session),
              if (session.fault != null) ...[
                const SizedBox(height: 12),
                Text(
                  session.fault!,
                  style: const TextStyle(
                    color: AppPalette.danger,
                    fontSize: AppTypeScale.caption,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Blocked extends StatelessWidget {
  const _Blocked();

  @override
  Widget build(BuildContext context) => const Text(
    'Stop the recording first — calibrating mid-session would change what the '
    'data already in it means.',
    style: TextStyle(color: AppPalette.warning),
  );
}

class _StepBody extends StatelessWidget {
  final ForceCalibrationSession session;

  const _StepBody({required this.session});

  @override
  Widget build(BuildContext context) => switch (session.step) {
    CalibrationStep.idle ||
    CalibrationStep.zeroPrompt => _ZeroPrompt(session: session),
    CalibrationStep.capturingZero => const _Capturing(
      label: 'Reading the unloaded zero…',
    ),
    CalibrationStep.weightPrompt => _WeightPrompt(session: session),
    CalibrationStep.capturingSpan => const _Capturing(
      label: 'Reading the loaded value…',
    ),
    CalibrationStep.review => _Review(session: session),
  };
}

class _ZeroPrompt extends StatelessWidget {
  final ForceCalibrationSession session;

  const _ZeroPrompt({required this.session});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Instruction(
        step: 'Step 1 of 2',
        title: 'Unload the oarlock',
        detail:
            'Take the oar out of the gate and let the oarlock hang free. Do not '
            'touch it while the reading is taken.',
      ),
      const SizedBox(height: 16),
      FButton(onPress: session.captureZero, child: const Text('Read zero')),
    ],
  );
}

class _WeightPrompt extends StatelessWidget {
  final ForceCalibrationSession session;

  const _WeightPrompt({required this.session});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Instruction(
        step: 'Step 2 of 2',
        title: 'Hang a known weight',
        detail:
            'Hang the weight from the pin, pulling the same way the rower does. '
            'Wait for it to stop swinging.',
      ),
      const SizedBox(height: 12),
      const Text(
        'Use the heaviest weight you can safely hang. A light one is '
        'extrapolated up to full rowing load, and its error with it.',
        style: TextStyle(
          color: AppPalette.warning,
          fontSize: AppTypeScale.caption,
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: 180,
        child: NumberInputField(
          key: const ValueKey('calibrationMass'),
          label: 'Weight',
          unit: 'kg',
          value: session.massKg,
          placeholder: '20',
          validate: _validateMass,
          onCommitted: session.setMass,
        ),
      ),
      const SizedBox(height: 16),
      FButton(
        onPress: session.massKg == null ? null : session.captureSpan,
        child: const Text('Read loaded value'),
      ),
    ],
  );
}

String? _validateMass(double value) =>
    value <= 0 ? 'Must be greater than 0' : null;

class _Capturing extends StatelessWidget {
  final String label;

  const _Capturing({required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppPalette.accent,
        ),
      ),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: AppPalette.mutedLabel)),
    ],
  );
}

class _Review extends StatelessWidget {
  final ForceCalibrationSession session;

  const _Review({required this.session});

  @override
  Widget build(BuildContext context) {
    final fitted = session.fitted!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Instruction(
          step: 'Review',
          title: 'Check this looks sane',
          detail:
              'The full-scale figure is what the sensor would read at the top '
              'of its range. A wildly implausible one means the weight moved.',
        ),
        const SizedBox(height: 16),
        _Row(
          label: 'Calibration load',
          value:
              '${fitted.spanNewtons.toStringAsFixed(1)} N '
              '(${session.massKg} kg)',
        ),
        _Row(
          label: 'Scale',
          value: '${fitted.scale.toStringAsFixed(4)} N/count',
        ),
        _Row(
          label: 'Full scale',
          value: '${fitted.fullScaleNewtons.toStringAsFixed(0)} N',
        ),
        if (session.isUnderloaded) ...[
          const SizedBox(height: 12),
          Text(
            'That weight is under '
            '${(minSpanFractionOfPeak * 100).round()}% of a typical peak '
            'load. The calibration will work, but its error is multiplied '
            'across the rowing range — a heavier weight is worth the trouble.',
            style: const TextStyle(
              color: AppPalette.warning,
              fontSize: AppTypeScale.caption,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FButton(
          onPress: () {
            session.commit();
            Navigator.pop(context);
          },
          child: const Text('Save calibration'),
        ),
        const SizedBox(height: 8),
        FButton(
          variant: FButtonVariant.outline,
          onPress: () => session.begin(session.oarlockKey!),
          child: const Text('Start over'),
        ),
      ],
    );
  }
}

class _Instruction extends StatelessWidget {
  final String step;
  final String title;
  final String detail;

  const _Instruction({
    required this.step,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        step,
        style: const TextStyle(
          color: AppPalette.accent,
          fontSize: AppTypeScale.caption,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        title,
        style: const TextStyle(
          color: AppPalette.label,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      Text(detail, style: const TextStyle(color: AppPalette.faintLabel)),
    ],
  );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppPalette.faintLabel)),
        Text(value, style: const TextStyle(color: AppPalette.label)),
      ],
    ),
  );
}
