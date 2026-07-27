import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config.dart';
import 'package:rudertelemetrie_mobile_app/services/rig/boat_config_store.dart';

import 'support/temp_documents.dart';

void main() {
  late Directory docs;
  late FileBoatConfigStore store;

  setUp(() {
    docs = useTempDocumentsDirectory();
    store = FileBoatConfigStore();
  });

  File writeConfig(String contents) =>
      File('${docs.path}/boat_config.json')..writeAsStringSync(contents);

  test('a missing file reads as nothing saved', () async {
    expect(await store.load(), isNull);
  });

  test('a corrupt file degrades to defaults and is moved aside', () async {
    final file = writeConfig('{"rigs": {');

    expect(await store.load(), isNull);
    expect(file.existsSync(), isFalse);
    expect(File('${file.path}.corrupt').existsSync(), isTrue);
  });

  test('an unexpected shape degrades to defaults', () async {
    writeConfig(jsonEncode({'rigs': 'nonsense', 'boatClass': 'quad'}));
    final data = await store.load();
    expect(data?.rigs, isEmpty);
  });

  test('round-trips a saved configuration', () async {
    await store.save(
      BoatConfigData(
        rigs: const {},
        boatClass: BoatClass.four,
        slots: const {},
      ),
    );

    expect((await store.load())?.boatClass, BoatClass.four);
  });
}
