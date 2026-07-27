import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/recording/session_store.dart';

void main() {
  test('formats and round-trips long-format rows', () {
    final csv = [
      'elapsed_ms,source,value',
      sessionCsvRow(0, 'Speed (km/h)', 18.0),
      sessionCsvRow(500, 'Speed (km/h)', 18.5),
      sessionCsvRow(500, 'Stroke Rate', 30.0),
    ].join('\n');

    final series = parseSessionCsv(csv);
    expect(series.keys.toSet(), {'Speed (km/h)', 'Stroke Rate'});
    expect(series['Speed (km/h)']!.map((s) => s.value), [18.0, 18.5]);
    expect(series['Speed (km/h)']!.first.elapsedMs, 0);
    expect(series['Stroke Rate']!.single.value, 30.0);
  });

  test('escapes and parses source names containing a comma', () {
    final row = sessionCsvRow(10, 'Force & Power (Oarlock 1, bow)', 42.0);
    expect(row.contains('"Force & Power (Oarlock 1, bow)"'), isTrue);

    final series = parseSessionCsv('elapsed_ms,source,value\n$row');
    expect(series.keys.single, 'Force & Power (Oarlock 1, bow)');
    expect(series.values.single.single.value, 42.0);
  });

  test('skips the header and malformed lines', () {
    final series = parseSessionCsv(
      'elapsed_ms,source,value\n\nbad,row\n5,X,1.5',
    );
    expect(series['X']!.single.value, 1.5);
    expect(series.length, 1);
  });
}
