import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Points `getApplicationDocumentsDirectory()` at a fresh temp directory for the
/// duration of one test, and returns it.
Directory useTempDocumentsDirectory() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = Directory.systemTemp.createTempSync('rudertelemetrie_test');
  final previous = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _TempPathProvider(dir.path);

  addTearDown(() {
    PathProviderPlatform.instance = previous;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  _TempPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}
