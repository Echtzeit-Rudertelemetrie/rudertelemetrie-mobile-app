import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/constants/unit.dart';
import 'package:rudertelemetrie_mobile_app/utils/format.dart';

void main() {
  group('formatElapsed', () {
    test('drops the hours component below one hour', () {
      expect(formatElapsed(const Duration(minutes: 5, seconds: 23)), '5:23');
      expect(formatElapsed(Duration.zero), '0:00');
      expect(formatElapsed(const Duration(seconds: 9)), '0:09');
    });

    test('promotes to h:mm:ss at the hour boundary', () {
      expect(formatElapsed(const Duration(minutes: 59, seconds: 59)), '59:59');
      expect(formatElapsed(const Duration(hours: 1)), '1:00:00');
      expect(
        formatElapsed(const Duration(hours: 1, minutes: 10, seconds: 4)),
        '1:10:04',
      );
    });
  });

  group('formatPace', () {
    test('reads as m:ss, not decimal seconds', () {
      expect(formatPace(128.5), '2:08');
      expect(formatPace(120), '2:00');
      expect(formatPace(65), '1:05');
    });

    test('has no pace for non-positive or non-finite input', () {
      expect(formatPace(0), '—');
      expect(formatPace(-1), '—');
      expect(formatPace(double.infinity), '—');
      expect(formatPace(double.nan), '—');
    });
  });

  group('formatDistance', () {
    test('switches from metres to kilometres at 1 km', () {
      expect(formatDistance(999), '999 m');
      expect(formatDistance(1000), '1.00 km');
      expect(formatDistance(1234.5), '1.23 km');
    });
  });

  test('units expose display labels, never the enum identifier', () {
    expect(Unit.kmh.label, 'km/h');
    expect(Unit.mps2.label, 'm/s²');
    expect(Unit.deg.label, '°');
    expect(Unit.pct.label, '%');
    expect(Unit.radps.label, 'rad/s');
    expect(Unit.pace.label, '/500m');
  });

  test(
    'formatValue renders a pace as m:ss and everything else numerically',
    () {
      expect(formatValue(128.5, Unit.pace), '2:08');
      expect(formatValue(128.5, Unit.N), '128.5');
    },
  );
}
