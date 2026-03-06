import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/parser/book-import-service.dart';

void main() {
  test('epub import extracts metadata and cover', () async {
    final file = await File(
      '${Directory.systemTemp.path}/uni_import_test.epub',
    ).create();
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
    final coverBytes = <int>[137, 80, 78, 71, 13, 10, 26, 10];

    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'META-INF/container.xml',
          containerXml.length,
          containerXml,
        ),
      )
      ..addFile(ArchiveFile('OEBPS/content.opf', opfXml.length, opfXml))
      ..addFile(
        ArchiveFile('OEBPS/images/cover.png', coverBytes.length, coverBytes),
      );

    final bytes = ZipEncoder().encode(archive);
    await file.writeAsBytes(bytes);

    final service = BookImportService();
    final result = await service.importFromPath(file.path);

    expect(result.format, 'epub');
    expect(result.title, 'Real Book Name');
    expect(result.author, 'Author A');
    expect(result.coverUrl, startsWith('data:image/png;base64,'));
    expect(result.sourceType, 'local_epub');
    expect(result.sourcePath, file.path);

    await file.delete();
  });

  test('epub import extracts metadata without cover', () async {
    final file = await File(
      '${Directory.systemTemp.path}/uni_import_no_cover.epub',
    ).create();
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
      '<dc:title>No Cover Book</dc:title>'
      '<dc:creator>Author B</dc:creator>'
      '</metadata>'
      '<manifest>'
      '<item id="c1" href="text/chapter1.xhtml" media-type="application/xhtml+xml"/>'
      '</manifest>'
      '<spine><itemref idref="c1"/></spine>'
      '</package>',
    );

    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'META-INF/container.xml',
          containerXml.length,
          containerXml,
        ),
      )
      ..addFile(ArchiveFile('OEBPS/content.opf', opfXml.length, opfXml));

    final bytes = ZipEncoder().encode(archive);
    await file.writeAsBytes(bytes);

    final service = BookImportService();
    final result = await service.importFromPath(file.path);

    expect(result.format, 'epub');
    expect(result.title, 'No Cover Book');
    expect(result.author, 'Author B');
    expect(result.coverUrl, isNull);

    await file.delete();
  });

  test('throws UnsupportedError for non-epub formats', () async {
    final file = await File(
      '${Directory.systemTemp.path}/uni_import_test.txt',
    ).create();
    await file.writeAsString('Some text content');

    final service = BookImportService();

    expect(
      () => service.importFromPath(file.path),
      throwsA(isA<UnsupportedError>()),
    );

    await file.delete();
  });

  test('throws FileSystemException for non-existent file', () async {
    final service = BookImportService();

    expect(
      () => service.importFromPath('/nonexistent/path/book.epub'),
      throwsA(isA<FileSystemException>()),
    );
  });
}
