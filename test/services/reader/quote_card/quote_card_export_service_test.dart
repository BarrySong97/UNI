import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/quote_card/quote_card_export_service.dart';

void main() {
  test('buildFileName sanitizes title and formats timestamp', () {
    final service = QuoteCardExportService(
      documentsDirectoryProvider: () async => Directory.systemTemp,
      tempDirectoryProvider: () async => Directory.systemTemp,
      shareFile: (_) async {},
    );

    final fileName = service.buildFileName(
      bookTitle: ' A Tale of Two Cities! ',
      now: DateTime(2026, 4, 8, 9, 20, 30),
    );

    expect(fileName, 'quote-card-a-tale-of-two-cities-20260408-092030.png');
  });

  test('savePng writes bytes into exports directory', () async {
    final tempDir = await Directory.systemTemp.createTemp('quote-card-test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final service = QuoteCardExportService(
      documentsDirectoryProvider: () async => tempDir,
      tempDirectoryProvider: () async => tempDir,
      shareFile: (_) async {},
    );

    final path = await service.savePng(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'quote-card-sample.png',
    );

    final file = File(path);
    expect(await file.exists(), isTrue);
    expect(path, contains('exports${Platform.pathSeparator}quote_cards'));
    expect(await file.readAsBytes(), <int>[1, 2, 3]);
  });

  test('savePng rejects empty bytes', () async {
    final service = QuoteCardExportService(
      documentsDirectoryProvider: () async => Directory.systemTemp,
      tempDirectoryProvider: () async => Directory.systemTemp,
      shareFile: (_) async {},
    );

    expect(
      () => service.savePng(bytes: Uint8List(0), fileName: 'empty.png'),
      throwsArgumentError,
    );
  });
}
