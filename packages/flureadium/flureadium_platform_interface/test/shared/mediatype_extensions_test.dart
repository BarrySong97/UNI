import 'package:flutter_test/flutter_test.dart';
import 'package:flureadium_platform_interface/src/shared/mediatype/mediatype_extensions.dart';

void main() {
  group('StringPathExtension', () {
    group('extension', () {
      test('extracts file extension without dot', () {
        expect('file.txt'.extension(), equals('txt'));
        expect('document.pdf'.extension(), equals('pdf'));
        expect('image.png'.extension(), equals('png'));
      });

      test('handles multiple dots in filename', () {
        expect('archive.tar.gz'.extension(), equals('gz'));
        expect('file.backup.json'.extension(), equals('json'));
      });

      test('handles paths with directories', () {
        expect('/path/to/file.txt'.extension(), equals('txt'));
        expect('relative/path/document.pdf'.extension(), equals('pdf'));
      });

      test('handles files without extension', () {
        expect('filename'.extension(), equals(''));
        expect('/path/to/noextension'.extension(), equals(''));
      });

      test('handles empty string', () {
        expect(''.extension(), equals(''));
      });

      test('handles hidden files', () {
        expect(
          '.gitignore'.extension(),
          equals(''),
        ); // Hidden file with no extension
        expect(
          '.hidden.txt'.extension(),
          equals('txt'),
        ); // Hidden file with .txt extension
      });

      test('handles common ebook formats', () {
        expect('book.epub'.extension(), equals('epub'));
        expect('document.xhtml'.extension(), equals('xhtml'));
        expect('page.html'.extension(), equals('html'));
        expect('text.xml'.extension(), equals('xml'));
      });

      test('handles uppercase extensions', () {
        expect('FILE.TXT'.extension(), equals('TXT'));
        expect('Document.PDF'.extension(), equals('PDF'));
      });

      test('handles dot at end of filename', () {
        expect('filename.'.extension(), equals(''));
      });
    });
  });
}
