import 'package:flutter_test/flutter_test.dart';
import 'package:uni/dtos/db/book-dto.dart';
import 'package:uni/dtos/db/highlight-dto.dart';
import 'package:uni/dtos/db/reading-progress-dto.dart';
import 'package:uni/services/db/app-database.dart';

void main() {
  test('deleteBookCascade removes scoped book data and keeps others', () async {
    final database = AppDatabase();
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    await database.upsertBook(
      BookDto(
        id: 'book-1',
        title: 'Book One',
        author: 'Author A',
        coverUrl: null,
        profileBgColor: '#FF223344',
        sourceType: 'local_epub',
        sourcePath: '/tmp/one.epub',
        epubFilePath: '/tmp/one.epub',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertBook(
      BookDto(
        id: 'book-2',
        title: 'Book Two',
        author: 'Author B',
        sourceType: 'local_epub',
        sourcePath: '/tmp/two.epub',
        epubFilePath: '/tmp/two.epub',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertProgress(
      ReadingProgressDto(
        bookId: 'book-1',
        locatorJson: '{"href":"/chapter1.xhtml"}',
        percent: 0.1,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertProgress(
      ReadingProgressDto(
        bookId: 'book-2',
        locatorJson: '{"href":"/chapter1.xhtml"}',
        percent: 0.2,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertHighlight(
      HighlightDto(
        id: 'h-1',
        bookId: 'book-1',
        locatorJson:
            '{"href":"/chapter1.xhtml","locations":{"cssSelector":"p"}}',
        selectedText: 'Book1',
        color: '#FFFFEB3B',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertHighlight(
      HighlightDto(
        id: 'h-2',
        bookId: 'book-2',
        locatorJson:
            '{"href":"/chapter1.xhtml","locations":{"cssSelector":"p"}}',
        selectedText: 'Book2',
        color: '#FFFFEB3B',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.addReadingTime(
      bookId: 'book-1',
      dateKey: '2026-03-01',
      deltaSeconds: 120,
    );
    await database.addReadingTime(
      bookId: 'book-2',
      dateKey: '2026-03-01',
      deltaSeconds: 60,
    );

    await database.deleteBookCascade('book-1');

    expect(await database.getBook('book-1'), isNull);
    expect(await database.getProgress('book-1'), isNull);
    expect(await database.listHighlights('book-1'), isEmpty);
    expect(await database.getBookReadingTimeSeconds('book-1'), 0);

    expect(await database.getBook('book-2'), isNotNull);
    expect(await database.getProgress('book-2'), isNotNull);
    expect(await database.listHighlights('book-2'), isNotEmpty);
    expect(await database.getBookReadingTimeSeconds('book-2'), 60);
  });
}
