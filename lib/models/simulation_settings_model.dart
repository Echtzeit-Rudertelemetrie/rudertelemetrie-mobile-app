import 'package:flutter/cupertino.dart';

class SimulationSettingsModel extends ChangeNotifier {
  int _frequency = 1;

  int get frequency => _frequency;

  void setFrequency(int frequency) {
    _frequency = frequency;
    notifyListeners();
  }
}
