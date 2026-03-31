import 'dart:async';
import 'dart:math';

class RandomNumberService {
  static const int _sampleRateHz = 5;

  final double min;
  final double max;
  final _controller = StreamController<double>.broadcast();
  late final Timer _timer;
  final _random = Random();

  RandomNumberService({required this.min, required this.max}) {
    _timer = Timer.periodic(
      Duration(milliseconds: (1000 / _sampleRateHz).round()),
      _onTick,
    );
  }

  void _onTick(Timer _) {
    _controller.add(min + _random.nextDouble() * (max - min));
  }

  Stream<double> get signal => _controller.stream;

  void dispose() {
    _timer.cancel();
    _controller.close();
  }
}
