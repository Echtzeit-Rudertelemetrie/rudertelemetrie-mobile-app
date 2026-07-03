// Firmware encodes force as a fraction of a 1000 N full scale into a uint16
// (see rowing_boat SimData::dolle): raw = forceN / 1000 * 65535.
const double _forceFullScaleNewtons = 1000.0;
const int _uint16Max = 65535;

double convertForceSensorData(int raw) {
  return raw / _uint16Max * _forceFullScaleNewtons;
}
