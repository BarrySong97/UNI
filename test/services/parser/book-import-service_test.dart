import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/parser/book-import-service.dart';

void main() {
  test('txt import creates readable chapters', () async {
    final file = await File('${Directory.systemTemp.path}/uni_import_test.txt').create();
    await file.writeAsString('Chapter 1\nHello reader\n\nChapter 2\nSecond part');

    final service = BookImportService();
    final result = await service.importFromPath(file.path);

    expect(result.format, 'txt');
    expect(result.sourceType, 'local_txt');
    expect(result.chapters.length, 2);
    expect(result.chapters.first.title.toLowerCase(), contains('chapter'));

    await file.delete();
  });

  test('pdf import creates placeholder chapter in MVP', () async {
    final file = await File('${Directory.systemTemp.path}/uni_import_test.pdf').create();
    await file.writeAsString('fake content');

    final service = BookImportService();
    final result = await service.importFromPath(file.path);

    expect(result.format, 'pdf');
    expect(result.chapters.length, 1);
    expect(result.chapters.first.content.toLowerCase(), contains('not implemented'));

    await file.delete();
  });
}
