import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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

  test('epub import extracts cover and chapters', () async {
    final file = await File('${Directory.systemTemp.path}/uni_import_test.epub').create();
    final containerXml = utf8.encode(
      '<?xml version="1.0"?>'
      '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
      '<rootfiles>'
      '<rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>'
      '</rootfiles>'
      '</container>',
    );
    final opfXml = utf8.encode(
      '<?xml version="1.0" encoding="utf-8"?>'
      '<package version="3.0" xmlns="http://www.idpf.org/2007/opf">'
      '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
      '<dc:title>Real Book Name</dc:title>'
      '<dc:creator>Author A</dc:creator>'
      '<meta name="cover" content="cover-image"/>'
      '</metadata>'
      '<manifest>'
      '<item id="cover-image" href="images/cover.png" media-type="image/png"/>'
      '<item id="c1" href="text/chapter1.xhtml" media-type="application/xhtml+xml"/>'
      '</manifest>'
      '<spine><itemref idref="c1"/></spine>'
      '</package>',
    );
    final chapterXml = utf8.encode('<html><body><h1>Hello</h1><p>Chapter content</p></body></html>');
    final coverBytes = <int>[137, 80, 78, 71, 13, 10, 26, 10];

    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'META-INF/container.xml',
          containerXml.length,
          containerXml,
        ),
      )
      ..addFile(
        ArchiveFile(
          'OEBPS/content.opf',
          opfXml.length,
          opfXml,
        ),
      )
      ..addFile(
        ArchiveFile(
          'OEBPS/text/chapter1.xhtml',
          chapterXml.length,
          chapterXml,
        ),
      )
      ..addFile(ArchiveFile('OEBPS/images/cover.png', coverBytes.length, coverBytes));

    final bytes = ZipEncoder().encode(archive);
    await file.writeAsBytes(bytes);

    final service = BookImportService();
    final result = await service.importFromPath(file.path);

    expect(result.format, 'epub');
    expect(result.title, 'Real Book Name');
    expect(result.author, 'Author A');
    expect(result.coverUrl, startsWith('data:image/png;base64,'));
    expect(result.chapters, isNotEmpty);

    await file.delete();
  });
}
