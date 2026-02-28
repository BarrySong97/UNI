import 'package:flutter/widgets.dart';

import '../repositories/book/book-repository-impl.dart';
import '../repositories/chapter/chapter-repository-impl.dart';
import '../repositories/highlight/highlight-repository-impl.dart';
import '../repositories/progress/progress-repository-impl.dart';
import '../services/db/app-database.dart';
import '../services/db/daos/books-dao.dart';
import '../services/db/daos/chapters-dao.dart';
import '../services/db/daos/highlights-dao.dart';
import '../services/db/daos/progress-dao.dart';
import '../services/parser/book-import-service.dart';
import '../stores/highlight/highlight-store.dart';
import '../stores/library/library-store.dart';
import '../stores/reader/reader-store.dart';
import 'app.dart';
import 'i18n/app-locale.dart';
import 'providers/app-providers.dart';

class AppBootstrapResult {
  AppBootstrapResult({required this.app});

  final Widget app;
}

class AppBootstrap {
  static Future<AppBootstrapResult> initialize() async {
    final database = AppDatabase();
    final booksDao = BooksDao(database: database);
    final chaptersDao = ChaptersDao(database: database);
    final progressDao = ProgressDao(database: database);
    final highlightsDao = HighlightsDao(database: database);

    final bookRepository = BookRepositoryImpl(booksDao: booksDao);
    final chapterRepository = ChapterRepositoryImpl(chaptersDao: chaptersDao);
    final progressRepository = ProgressRepositoryImpl(progressDao: progressDao);
    final highlightRepository = HighlightRepositoryImpl(highlightsDao: highlightsDao);

    await _seedIfNeeded(bookRepository: bookRepository, chapterRepository: chapterRepository);

    final appLocale = AppLocaleController();
    await appLocale.initialize();

    final providers = AppProviders(
      bookRepository: bookRepository,
      chapterRepository: chapterRepository,
      progressRepository: progressRepository,
      highlightRepository: highlightRepository,
      appLocaleController: appLocale,
    );

    providers.registerStores(
      libraryStore: LibraryStore(
        bookRepository: bookRepository,
        chapterRepository: chapterRepository,
        bookImportService: BookImportService(),
      ),
      readerStore: ReaderStore(
        bookRepository: bookRepository,
        chapterRepository: chapterRepository,
        progressRepository: progressRepository,
      ),
      highlightStore: HighlightStore(highlightRepository: highlightRepository),
    );

    return AppBootstrapResult(app: UniApp(providers: providers));
  }

  static Future<void> _seedIfNeeded({
    required BookRepositoryImpl bookRepository,
    required ChapterRepositoryImpl chapterRepository,
  }) async {
    final books = await bookRepository.getShelfBooks();
    if (books.isNotEmpty) {
      return;
    }

    final now = DateTime.now();
    await bookRepository.upsertSeedBook(
      id: 'book-demo',
      title: 'Demo Book',
      author: 'Uni Team',
      createdAt: now,
      updatedAt: now,
    );

    await chapterRepository.upsertSeedChapter(
      id: 'chapter-1',
      bookId: 'book-demo',
      idx: 0,
      title: 'Chapter 1',
      content:
          'This is a demo chapter for MVP reader. You can select text to create highlights and verify persistence logic.',
    );

    await chapterRepository.upsertSeedChapter(
      id: 'chapter-2',
      bookId: 'book-demo',
      idx: 1,
      title: 'Chapter 2',
      content: 'Second chapter text for testing chapter switch and reading progress behaviors.',
    );
  }
}
