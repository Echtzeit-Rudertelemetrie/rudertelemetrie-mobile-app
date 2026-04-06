import 'dart:async';
import 'dart:math';

import 'stream_registry.dart';

/// Creates and registers a set of example data streams.
///
/// Call [start] to begin generating data and [stop] to clean up.
/// This class has no dependency on the rest of the app.
class ExampleStreams {
  final _controllers = <String, StreamController<double>>{};
  final _timers = <Timer>[];

  void start() {
    _addSine(key: 'sine_1hz', label: 'Sine 1 Hz', unit: '', freqHz: 1, sampleRateHz: 60, minY: -1.2, maxY: 1.2);
    _addSine(key: 'sine_2hz', label: 'Sine 2 Hz', unit: '', freqHz: 2, sampleRateHz: 60, minY: -1.2, maxY: 1.2);
    _addRandom(key: 'heart_rate', label: 'Heart Rate', unit: 'bpm', min: 60, max: 180, sampleRateHz: 5);
    _addRandom(key: 'power', label: 'Power', unit: 'W', min: 100, max: 400, sampleRateHz: 5);
  }

  void stop() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    for (final entry in _controllers.entries) {
      entry.value.close();
      StreamRegistry.unregister(entry.key);
    }
    _controllers.clear();
  }

  void _addSine({
    required String key,
    required String label,
    required String unit,
    required int freqHz,
    required int sampleRateHz,
    double? minY,
    double? maxY,
  }) {
    final ctrl = StreamController<double>.broadcast();
    _controllers[key] = ctrl;
    double elapsed = 0;
    final interval = Duration(microseconds: (1e6 / sampleRateHz).round());
    _timers.add(Timer.periodic(interval, (_) {
      elapsed += 1.0 / sampleRateHz;
      ctrl.add(sin(2 * pi * freqHz * elapsed));
    }));
    StreamRegistry.register(StreamInfo(
      key: key,
      label: label,
      unit: unit,
      stream: ctrl.stream,
      minY: minY,
      maxY: maxY,
    ));
  }

  void _addRandom({
    required String key,
    required String label,
    required String unit,
    required double min,
    required double max,
    required int sampleRateHz,
  }) {
    final ctrl = StreamController<double>.broadcast();
    _controllers[key] = ctrl;
    final rng = Random();
    final interval = Duration(milliseconds: (1000 / sampleRateHz).round());
    _timers.add(Timer.periodic(interval, (_) {
      ctrl.add(min + rng.nextDouble() * (max - min));
    }));
    StreamRegistry.register(StreamInfo(
      key: key,
      label: label,
      unit: unit,
      stream: ctrl.stream,
      minY: min,
      maxY: max,
    ));
  }
}
