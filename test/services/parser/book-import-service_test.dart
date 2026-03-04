import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/parser/book-import-service.dart';

void main() {
  test('txt import creates readable chapters', () async {
    final file = await File(
      '${Directory.systemTemp.path}/uni_import_test.txt',
    ).create();
    await file.writeAsString(
      'Chapter 1\nHello reader\n\nChapter 2\nSecond part',
    );

    final service = BookImportService();
    final result = await service.importFromPath(file.path);

    expect(result.format, 'txt');
    expect(result.sourceType, 'local_txt');
    expect(result.chapters.length, 2);
    expect(result.chapters.first.title.toLowerCase(), contains('chapter'));

    await file.delete();
  });

  test(
    'txt import infers chapter title from content when no explicit header',
    () async {
      final file = await File(
        '${Directory.systemTemp.path}/uni_import_plain_text.txt',
      ).create();
      await file.writeAsString('Preface line\nBody paragraph\nAnother line');

      final service = BookImportService();
      final result = await service.importFromPath(file.path);

      expect(result.chapters.length, 1);
      expect(result.chapters.first.title, 'Preface line');

      await file.delete();
    },
  );

  test('pdf import creates placeholder chapter in MVP', () async {
    final file = await File(
      '${Directory.systemTemp.path}/uni_import_test.pdf',
    ).create();
    await file.writeAsString('fake content');

    final service = BookImportService();
    final result = await service.importFromPath(file.path);

    expect(result.format, 'pdf');
    expect(result.chapters.length, 1);
    expect(
      result.chapters.first.content.toLowerCase(),
      contains('not implemented'),
    );

    await file.delete();
  });

  test('epub import extracts cover and chapters', () async {
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
    final chapterXml = utf8.encode(
      '<html><body><h1>Hello</h1><p>Chapter content</p></body></html>',
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
        ArchiveFile('OEBPS/text/chapter1.xhtml', chapterXml.length, chapterXml),
      )
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
    expect(result.chapters, isNotEmpty);
    expect(result.chapters.first.title, 'Hello');

    await file.delete();
  });

  test('epub import follows spine order for chapter sequence', () async {
    final file = await File(
      '${Directory.systemTemp.path}/uni_import_spine_order.epub',
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
      '<dc:title>Ordered Book</dc:title>'
      '<dc:creator>Author B</dc:creator>'
      '</metadata>'
      '<manifest>'
      '<item id="c2" href="text/chapter2.xhtml" media-type="application/xhtml+xml"/>'
      '<item id="c1" href="text/chapter1.xhtml" media-type="application/xhtml+xml"/>'
      '</manifest>'
      '<spine><itemref idref="c2"/><itemref idref="c1"/></spine>'
      '</package>',
    );
    final chapter1Xml = utf8.encode(
      '<html><body><h1>Second Chapter</h1><p>Second chapter text</p></body></html>',
    );
    final chapter2Xml = utf8.encode(
      '<html><body><h1>First Chapter</h1><p>First chapter text</p></body></html>',
    );

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
        ArchiveFile(
          'OEBPS/text/chapter1.xhtml',
          chapter1Xml.length,
          chapter1Xml,
        ),
      )
      ..addFile(
        ArchiveFile(
          'OEBPS/text/chapter2.xhtml',
          chapter2Xml.length,
          chapter2Xml,
        ),
      );

    final bytes = ZipEncoder().encode(archive);
    await file.writeAsBytes(bytes);

    final service = BookImportService();
    final result = await service.importFromPath(file.path);

    expect(result.chapters, hasLength(2));
    expect(result.chapters[0].title, 'First Chapter');
    expect(result.chapters[1].title, 'Second Chapter');

    await file.delete();
  });

  test('epub import prefers TOC title over body heading', () async {
    final file = await File(
      '${Directory.systemTemp.path}/uni_import_toc_title.epub',
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
      '<dc:title>TOC Book</dc:title>'
      '<dc:creator>Author C</dc:creator>'
      '</metadata>'
      '<manifest>'
      '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
      '<item id="c1" href="text/ch1.xhtml" media-type="application/xhtml+xml"/>'
      '</manifest>'
      '<spine><itemref idref="c1"/></spine>'
      '</package>',
    );
    final navXml = utf8.encode(
      '<html><body><nav epub:type="toc"><ol>'
      '<li><a href="text/ch1.xhtml">TOC Chapter Name</a></li>'
      '</ol></nav></body></html>',
    );
    final chapterXml = utf8.encode(
      '<html><body><h1>Body Heading</h1><p>Body text</p></body></html>',
    );

    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'META-INF/container.xml',
          containerXml.length,
          containerXml,
        ),
      )
      ..addFile(ArchiveFile('OEBPS/content.opf', opfXml.length, opfXml))
      ..addFile(ArchiveFile('OEBPS/nav.xhtml', navXml.length, navXml))
      ..addFile(
        ArchiveFile('OEBPS/text/ch1.xhtml', chapterXml.length, chapterXml),
      );

    final bytes = ZipEncoder().encode(archive);
    await file.writeAsBytes(bytes);

    final service = BookImportService();
    final result = await service.importFromPath(file.path);

    expect(result.chapters, isNotEmpty);
    expect(result.chapters.first.title, 'TOC Chapter Name');

    await file.delete();
  });

  test('epub import splits oversized chapter content into parts', () async {
    final file = await File(
      '${Directory.systemTemp.path}/uni_import_large_chapter.epub',
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
      '<dc:title>Big Book</dc:title>'
      '<dc:creator>Author D</dc:creator>'
      '</metadata>'
      '<manifest>'
      '<item id="c1" href="text/ch1.xhtml" media-type="application/xhtml+xml"/>'
      '</manifest>'
      '<spine><itemref idref="c1"/></spine>'
      '</package>',
    );
    final paragraph = List<String>.filled(
      80,
      'very long paragraph text',
    ).join(' ');
    final chapterBody = List<String>.filled(120, '<p>$paragraph</p>').join();
    final chapterXml = utf8.encode(
      '<html><body><h1>Big Chapter</h1>$chapterBody</body></html>',
    );

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
        ArchiveFile('OEBPS/text/ch1.xhtml', chapterXml.length, chapterXml),
      );

    final bytes = ZipEncoder().encode(archive);
    await file.writeAsBytes(bytes);

    final service = BookImportService();
    final result = await service.importFromPath(file.path);

    expect(result.chapters.length, greaterThan(1));
    expect(result.chapters.first.title, 'Big Chapter');
    expect(result.chapters[1].title, contains('Big Chapter'));

    await file.delete();
  });
}
