import 'package:provider/provider.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration_session.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration_store.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibrations.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/recording_session.dart';
import 'package:rudertelemetrie_mobile_app/services/stroke/stroke_engine.dart';

final forceCalibrationsProvider = ChangeNotifierProvider<ForceCalibrations>(
  create: (_) => ForceCalibrations(store: FileForceCalibrationStore())..load(),
);

final forceCalibrationSessionProvider =
    ChangeNotifierProvider<ForceCalibrationSession>(
      create: (context) => ForceCalibrationSession(
        calibrations: context.read<ForceCalibrations>(),
        engine: context.read<StrokeEngine>(),
        recording: context.read<RecordingSession>(),
      ),
    );
