// Firmware encodes angle over a -180..+180 degree full scale into a uint16
// (see rowing_boat SimData::dolle): raw = (angleDeg + 180) / 360 * 65535.
const double _angleMinDegrees = -180.0;
const double _angleFullScaleDegrees = 360.0;
const int _uint16Max = 65535;

double convertAngleSensorData(int raw) =>
    _angleMinDegrees + raw / _uint16Max * _angleFullScaleDegrees;
