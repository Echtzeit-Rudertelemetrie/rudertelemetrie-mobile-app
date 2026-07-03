// Firmware encodes angle over a -90..+90 degree full scale into a uint16
// (see rowing_boat SimData::dolle): raw = (angleDeg + 90) / 180 * 65535.
const double _angleFullScaleDegrees = 180.0;
const double _angleOffsetDegrees = 90.0;
const int _uint16Max = 65535;

double convertAngleSensorData(int raw) {
  return raw / _uint16Max * _angleFullScaleDegrees - _angleOffsetDegrees;
}
