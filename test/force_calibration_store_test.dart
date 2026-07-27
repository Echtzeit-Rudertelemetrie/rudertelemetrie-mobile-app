import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration.dart';
import 'package:rudertelemetrie_mobile_app/services/calibration/force_calibration_store.dart';

import 'support/temp_documents.dart';

void main() {
  late Directory docs;
  late FileForceCalibrationStore store;

  setUp(() {
    docs = useTempDocumentsDirectory();
    store = FileForceCalibrationStore();
  });

  File writeStored(String contents) =>
      File('${docs.path}/force_calibration.json')..writeAsStringSync(contents);

  final calibration = ForceCalibration.fit(
    zeroRaw: 1000,
    loadedRaw: 11000,
    massKg: 20,
    at: DateTime(2026, 7, 27),
  )!;

  test('a missing file reads as nothing saved', () async {
    expect(await store.load(), isNull);
  });

  test('a corrupt file degrades to defaults and is moved aside', () async {
    final file = writeStored('{"calibrations": {');

    expect(await store.load(), isNull);
    expect(file.existsSync(), isFalse);
    expect(File('${file.path}.corrupt').existsSync(), isTrue);
  });

  test('an unexpected shape degrades to defaults', () async {
    writeStored(jsonEncode({'calibrations': 'nonsense'}));

    expect(await store.load(), isEmpty);
  });

  test('round-trips a saved calibration', () async {
    await store.save({'Oarlock 1 (EE01)': calibration});

    expect(await store.load(), {'Oarlock 1 (EE01)': calibration});
  });

  test('drops an entry whose span would divide by zero', () async {
    writeStored(
      jsonEncode({
        'calibrations': {
          'Oarlock 1 (EE01)': {
            'zeroRaw': 1000.0,
            'spanRaw': 1000.0,
            'spanNewtons': 196.0,
            'calibratedAt': '2026-07-27T00:00:00.000',
          },
        },
      }),
    );

    expect(await store.load(), isEmpty);
  });

  test('keeps the good entries alongside a dropped one', () async {
    await store.save({
      'Oarlock 1 (EE01)': calibration,
      'Oarlock 2 (EE01)': const ForceCalibration(
        zeroRaw: 500,
        spanRaw: 500,
        spanNewtons: 196,
      ),
    });

    expect(await store.load(), {'Oarlock 1 (EE01)': calibration});
  });
}
