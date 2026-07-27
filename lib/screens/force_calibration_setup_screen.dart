import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/providers/data_source_provider.dart';
import 'package:rudertelemetrie_mobile_app/screens/force_calibration_screen.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibrations.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/oarlocks.dart';
import 'package:rudertelemetrie_mobile_app/theme/app_palette.dart';

/// Setup → Force Calibration: which oarlocks read in real newtons, and which
/// are still on the nominal firmware scale.
class ForceCalibrationSetupScreen extends StatelessWidget {
  const ForceCalibrationSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<DataSourceProviderModel>().registry;
    final calibrations = context.watch<ForceCalibrations>();
    final keys = connectedOarlockKeys(registry).toList()..sort();

    return FScaffold(
      header: FHeader.nested(
        title: const Text('Force Calibration'),
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
                    _OarlockCalibration(
                      key: ValueKey(key),
                      oarlockKey: key,
                      calibration: calibrations.calibrationFor(key),
                      driftNewtons: calibrations.offsetFor(key),
                      needsRecalibration: calibrations.needsRecalibration(key),
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
        'Connect an oarlock to calibrate its force sensor.',
        style: TextStyle(color: Colors.white54),
      ),
    ),
  );
}

class _OarlockCalibration extends StatelessWidget {
  final String oarlockKey;
  final ForceCalibration calibration;
  final double driftNewtons;
  final bool needsRecalibration;

  const _OarlockCalibration({
    super.key,
    required this.oarlockKey,
    required this.calibration,
    required this.driftNewtons,
    required this.needsRecalibration,
  });

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
        const SizedBox(height: 6),
        _status(),
        const SizedBox(height: 4),
        _drift(),
        if (needsRecalibration) ...[
          const SizedBox(height: 4),
          const Text(
            'The zero has drifted further than a healthy sensor should. '
            'Recalibrate before trusting these readings.',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: AppTypeScale.caption,
            ),
          ),
        ],
        const SizedBox(height: 8),
        FButton(
          variant: FButtonVariant.outline,
          onPress: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ForceCalibrationScreen(oarlockKey: oarlockKey),
            ),
          ),
          child: Text(calibration.isCalibrated ? 'Recalibrate' : 'Calibrate'),
        ),
      ],
    ),
  );

  Widget _status() {
    final at = calibration.calibratedAt;
    final (text, color) = at == null
        ? (
            'Not calibrated — readings are on the nominal firmware scale and '
                'are proportional to force, not newtons.',
            Colors.amber,
          )
        : (
            'Calibrated ${_date(at)} · '
                '${calibration.spanNewtons.toStringAsFixed(0)} N reference',
            Colors.greenAccent,
          );
    return Text(
      text,
      style: TextStyle(color: color, fontSize: AppTypeScale.caption),
    );
  }

  /// The live zero offset is the honest indicator of whether a sensor is
  /// behaving; a rower can watch it rather than guess.
  Widget _drift() => Text(
    'Zero drift being removed: ${driftNewtons.toStringAsFixed(1)} N',
    style: const TextStyle(
      color: Colors.white38,
      fontSize: AppTypeScale.caption,
    ),
  );

  static String _date(DateTime at) =>
      '${at.year}-${_two(at.month)}-${_two(at.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}
