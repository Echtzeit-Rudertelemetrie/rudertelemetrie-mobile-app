// Production firmware encodes -180..+180 degrees into the uint16 range.
const double _angleMinimumDegrees = -180.0;
const double _angleSpanDegrees = 360.0;
const int _uint16Max = 65535;

double convertAngleSensorData(int raw) {
  return _angleMinimumDegrees + raw / _uint16Max * _angleSpanDegrees;
}
