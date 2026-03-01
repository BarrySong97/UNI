import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/repositories/book/book-repository-impl.dart';
import 'package:uni/repositories/chapter/chapter-repository-impl.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/books-dao.dart';
import 'package:uni/services/db/daos/chapters-dao.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
import 'package:uni/stores/reader/reader-store.dart';

void main() {
  test('openBook restores chapter and charOffset from progress', () async {
    final database = AppDatabase();
    final bookRepository = BookRepositoryImpl(
      booksDao: BooksDao(database: database),
    );
    final chapterRepository = ChapterRepositoryImpl(
      chaptersDao: ChaptersDao(database: database),
    );
    final progressRepository = ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    );

    final now = DateTime.now();
    await bookRepository.upsertSeedBook(
      id: 'book-1',
      title: 'Book 1',
      author: 'Author',
      createdAt: now,
      updatedAt: now,
    );
    await chapterRepository.upsertSeedChapter(
      id: 'chapter-1',
      bookId: 'book-1',
      idx: 0,
      title: 'Chapter 1',
      content: 'hello world chapter one',
    );

    await progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: 'book-1',
        chapterId: 'chapter-1',
        charOffset: 5,
        percent: 0.25,
        updatedAt: now,
      ),
    );

    final store = ReaderStore(
      bookRepository: bookRepository,
      chapterRepository: chapterRepository,
      progressRepository: progressRepository,
    );

    await store.openBook('book-1');

    expect(store.state.chapter?.id, 'chapter-1');
    expect(store.state.charOffset, 5);
  });

  test('flushProgress forces save immediately', () async {
    final database = AppDatabase();
    final bookRepository = BookRepositoryImpl(
      booksDao: BooksDao(database: database),
    );
    final chapterRepository = ChapterRepositoryImpl(
      chaptersDao: ChaptersDao(database: database),
    );
    final progressRepository = ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    );

    final now = DateTime.now();
    await bookRepository.upsertSeedBook(
      id: 'book-2',
      title: 'Book 2',
      author: 'Author',
      createdAt: now,
      updatedAt: now,
    );
    await chapterRepository.upsertSeedChapter(
      id: 'chapter-2',
      bookId: 'book-2',
      idx: 0,
      title: 'Chapter 2',
      content: 'abcdefg',
    );

    final store = ReaderStore(
      bookRepository: bookRepository,
      chapterRepository: chapterRepository,
      progressRepository: progressRepository,
    );

    await store.openBook('book-2');
    store.updateOffset(4);
    await store.flushProgress();

    final saved = await progressRepository.getProgress('book-2');
    expect(saved?.charOffset, 4);
  });

  test('flushProgress can save silently without emitting listeners', () async {
    final database = AppDatabase();
    final bookRepository = BookRepositoryImpl(
      booksDao: BooksDao(database: database),
    );
    final chapterRepository = ChapterRepositoryImpl(
      chaptersDao: ChaptersDao(database: database),
    );
    final progressRepository = ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    );

    final now = DateTime.now();
    await bookRepository.upsertSeedBook(
      id: 'book-3',
      title: 'Book 3',
      author: 'Author',
      createdAt: now,
      updatedAt: now,
    );
    await chapterRepository.upsertSeedChapter(
      id: 'chapter-3',
      bookId: 'book-3',
      idx: 0,
      title: 'Chapter 3',
      content: 'abcdefghijk',
    );

    final store = ReaderStore(
      bookRepository: bookRepository,
      chapterRepository: chapterRepository,
      progressRepository: progressRepository,
    );
    var notifyCount = 0;
    store.addListener(() {
      notifyCount++;
    });

    await store.openBook('book-3');
    store.updateOffset(6);
    notifyCount = 0;

    await store.flushProgress(emitStateChanges: false);

    final saved = await progressRepository.getProgress('book-3');
    expect(saved?.charOffset, 6);
    expect(notifyCount, 0);
  });
}
