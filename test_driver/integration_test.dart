import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [
      Map<String, Object?>? args,
    ]) async {
      final dirPath = Platform.environment['SCREENSHOT_DIR'] ?? 'screenshots';
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/$name.png');
      await file.writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}
