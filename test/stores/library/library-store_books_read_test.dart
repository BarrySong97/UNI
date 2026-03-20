import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/repositories/book/book-repository-impl.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/books-dao.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
import 'package:uni/services/library/book-profile-color-service.dart';
import 'package:uni/services/parser/book-import-service.dart';
import 'package:uni/services/reader/epub_preparse_service.dart';
import 'package:uni/stores/library/library-store.dart';

class _FakeBookImportService extends BookImportService {
  @override
  Future<ImportedBookDraft> importFromPath(String path) {
    throw UnimplementedError('Not used in this test.');
  }
}

void main() {
  test('loadShelf and refreshProgress update booksReadThisYear', () async {
    final database = AppDatabase();
    final bookRepository = BookRepositoryImpl(
      booksDao: BooksDao(database: database),
    );
    final progressRepository = ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    );
    final now = DateTime.now();
    final currentYear = now.year;

    Future<void> seedBook(String id) {
      return bookRepository.upsertBook(
        BookEntity(
          id: id,
          title: id,
          author: 'Author',
          sourceType: 'local_epub',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    Future<void> seedProgress(String id, double percent) {
      return progressRepository.saveProgress(
        ReadingProgressEntity(
          bookId: id,
          locatorJson: '{}',
          percent: percent,
          updatedAt: now,
        ),
      );
    }

    await seedBook('book-1');
    await seedBook('book-2');
    await seedProgress('book-1', 0.4);
    await seedProgress('book-2', 0.9);
    await database.addReadingTime(
      bookId: 'book-1',
      dateKey: '$currentYear-01-05',
      deltaSeconds: 1200,
    );
    await database.addReadingTime(
      bookId: 'book-2',
      dateKey: '$currentYear-01-06',
      deltaSeconds: 1100,
    );

    final store = LibraryStore(
      bookRepository: bookRepository,
      bookImportService: _FakeBookImportService(),
      booksDirectory: '/tmp',
      progressRepository: progressRepository,
      database: database,
      bookProfileColorService: const BookProfileColorService(),
      epubPreparseService: EpubPreparseService(),
    );

    await store.loadShelf();
    expect(store.state.booksReadThisYear, 1);

    await database.addReadingTime(
      bookId: 'book-2',
      dateKey: '$currentYear-01-07',
      deltaSeconds: 100,
    );
    await store.refreshProgress();
    expect(store.state.booksReadThisYear, 2);
  });
}
