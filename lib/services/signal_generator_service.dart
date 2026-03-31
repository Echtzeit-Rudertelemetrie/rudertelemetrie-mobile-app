import 'dart:async';

import 'package:rudertelemetrie_mobile_app/utils/signal_generator.dart';

class SignalGeneratorService {
  static const int _sampleRateHz = 240;

  final int frequency;
  final _controller = StreamController<double>.broadcast();
  late final Timer _timer;
  double _elapsed = 0;

  SignalGeneratorService({required this.frequency}) {
    _timer = Timer.periodic(
      Duration(microseconds: (1e6 / _sampleRateHz).round()),
      _onTick,
    );
  }

  void _onTick(Timer _) {
    _elapsed += 1.0 / _sampleRateHz;
    _controller.add(generateSine(frequency, _elapsed));
  }

  Stream<double> get signal => _controller.stream;

  void dispose() {
    _timer.cancel();
    _controller.close();
  }
}
