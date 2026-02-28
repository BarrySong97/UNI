import 'package:flutter/foundation.dart';
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
    final database = kIsWeb ? AppDatabase() : await AppDatabase.openPersistent();
    final booksDao = BooksDao(database: database);
    final chaptersDao = ChaptersDao(database: database);
    final progressDao = ProgressDao(database: database);
    final highlightsDao = HighlightsDao(database: database);

    final bookRepository = BookRepositoryImpl(booksDao: booksDao);
    final chapterRepository = ChapterRepositoryImpl(chaptersDao: chaptersDao);
    final progressRepository = ProgressRepositoryImpl(progressDao: progressDao);
    final highlightRepository = HighlightRepositoryImpl(highlightsDao: highlightsDao);

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
}
