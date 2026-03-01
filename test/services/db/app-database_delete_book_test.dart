import 'package:flutter_test/flutter_test.dart';
import 'package:uni/dtos/db/book-dto.dart';
import 'package:uni/dtos/db/chapter-dto.dart';
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
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertChapter(
      ChapterDto(
        id: 'book-1-c1',
        bookId: 'book-1',
        idx: 0,
        title: 'Chapter 1',
        content: 'Content',
        wordCount: 7,
      ),
    );
    await database.upsertChapter(
      ChapterDto(
        id: 'book-2-c1',
        bookId: 'book-2',
        idx: 0,
        title: 'Chapter 1',
        content: 'Content',
        wordCount: 7,
      ),
    );
    await database.upsertProgress(
      ReadingProgressDto(
        bookId: 'book-1',
        chapterId: 'book-1-c1',
        charOffset: 10,
        percent: 0.1,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertProgress(
      ReadingProgressDto(
        bookId: 'book-2',
        chapterId: 'book-2-c1',
        charOffset: 20,
        percent: 0.2,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertHighlight(
      HighlightDto(
        id: 'h-1',
        bookId: 'book-1',
        chapterId: 'book-1-c1',
        startOffset: 0,
        endOffset: 5,
        selectedText: 'Book1',
        prefixContext: '',
        suffixContext: '',
        color: '#FFFFEB3B',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );
    await database.upsertHighlight(
      HighlightDto(
        id: 'h-2',
        bookId: 'book-2',
        chapterId: 'book-2-c1',
        startOffset: 0,
        endOffset: 5,
        selectedText: 'Book2',
        prefixContext: '',
        suffixContext: '',
        color: '#FFFFEB3B',
        createdAtMillis: nowMillis,
        updatedAtMillis: nowMillis,
      ),
    );

    await database.deleteBookCascade('book-1');

    expect(await database.getBook('book-1'), isNull);
    expect(await database.listChaptersByBook('book-1'), isEmpty);
    expect(await database.getProgress('book-1'), isNull);
    expect(await database.listHighlights('book-1'), isEmpty);

    expect(await database.getBook('book-2'), isNotNull);
    expect(await database.listChaptersByBook('book-2'), isNotEmpty);
    expect(await database.getProgress('book-2'), isNotNull);
    expect(await database.listHighlights('book-2'), isNotEmpty);
  });
}
