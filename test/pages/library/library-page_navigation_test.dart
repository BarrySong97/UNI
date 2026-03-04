import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/app/i18n/app-locale.dart';
import 'package:uni/app/i18n/app-localizations.dart';
import 'package:uni/app/providers/app-providers.dart';
import 'package:uni/app/routes/route-names.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/entities/chapter-entity.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/pages/library/library-page.dart';
import 'package:uni/repositories/book/book-repository-impl.dart';
import 'package:uni/repositories/chapter/chapter-repository-impl.dart';
import 'package:uni/repositories/highlight/highlight-repository-impl.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/repositories/reader-pagination-cache/reader-pagination-cache-repository-impl.dart';
import 'package:uni/repositories/reader-preferences/reader-preferences-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/books-dao.dart';
import 'package:uni/services/db/daos/chapters-dao.dart';
import 'package:uni/services/db/daos/highlights-dao.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
import 'package:uni/services/db/daos/reader-pagination-cache-dao.dart';
import 'package:uni/services/db/daos/reader-preferences-dao.dart';
import 'package:uni/services/library/book-profile-entry-service.dart';
import 'package:uni/services/parser/book-import-service.dart';
import 'package:uni/stores/highlight/highlight-store.dart';
import 'package:uni/stores/library/library-store.dart';
import 'package:uni/stores/reader/reader-store.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}

Future<AppProviders> _createProviders({required bool hasProgress}) async {
  final database = AppDatabase();
  final booksDao = BooksDao(database: database);
  final chaptersDao = ChaptersDao(database: database);
  final progressDao = ProgressDao(database: database);
  final highlightsDao = HighlightsDao(database: database);
  final readerPaginationCacheDao = ReaderPaginationCacheDao(database: database);
  final readerPreferencesDao = ReaderPreferencesDao(database: database);

  final bookRepository = BookRepositoryImpl(booksDao: booksDao);
  final chapterRepository = ChapterRepositoryImpl(chaptersDao: chaptersDao);
  final progressRepository = ProgressRepositoryImpl(progressDao: progressDao);
  final highlightRepository = HighlightRepositoryImpl(
    highlightsDao: highlightsDao,
  );
  final readerPreferencesRepository = ReaderPreferencesRepositoryImpl(
    preferencesDao: readerPreferencesDao,
  );
  final readerPaginationCacheRepository = ReaderPaginationCacheRepositoryImpl(
    cacheDao: readerPaginationCacheDao,
  );

  final now = DateTime.now();
  await bookRepository.upsertBook(
    BookEntity(
      id: 'book-1',
      title: 'Architecture of Happiness',
      author: 'Alain de Botton',
      sourceType: 'local_epub',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await chapterRepository.upsertChapter(
    ChapterEntity(
      id: 'book-1-c1',
      bookId: 'book-1',
      idx: 0,
      title: 'Chapter 1',
      content: 'Reader content',
      wordCount: 14,
    ),
  );
  if (hasProgress) {
    await progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: 'book-1',
        chapterId: 'book-1-c1',
        charOffset: 90,
        percent: 0.2,
        updatedAt: now,
      ),
    );
  }

  final providers = AppProviders(
    bookRepository: bookRepository,
    chapterRepository: chapterRepository,
    progressRepository: progressRepository,
    highlightRepository: highlightRepository,
    readerPaginationCacheRepository: readerPaginationCacheRepository,
    readerPreferencesRepository: readerPreferencesRepository,
    bookProfileEntryService: BookProfileEntryService(
      progressRepository: progressRepository,
    ),
    appLocaleController: AppLocaleController(),
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
      readerPaginationCacheRepository: readerPaginationCacheRepository,
      readerPreferencesRepository: readerPreferencesRepository,
    ),
    highlightStore: HighlightStore(highlightRepository: highlightRepository),
  );
  return providers;
}

Widget _buildApp({
  required AppProviders providers,
  required NavigatorObserver observer,
}) {
  return AppProvidersScope(
    providers: providers,
    child: MaterialApp(
      supportedLocales: AppLocaleController.supportedLocales,
      localizationsDelegates: AppLocalizations.delegates,
      navigatorObservers: <NavigatorObserver>[observer],
      onGenerateRoute: (settings) {
        if (settings.name == RouteNames.bookDetail) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('book-detail')),
          );
        }
        if (settings.name == RouteNames.reader) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('reader')),
          );
        }
        return null;
      },
      home: const Scaffold(body: LibraryPage()),
    ),
  );
}

void main() {
  testWidgets('first open routes to book detail profile', (tester) async {
    final providers = await _createProviders(hasProgress: false);
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      _buildApp(providers: providers, observer: observer),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Architecture of Happiness'));
    await tester.pumpAndSettle();

    expect(observer.pushedRouteNames, contains(RouteNames.bookDetail));
  });

  testWidgets('book with progress routes directly to reader', (tester) async {
    final providers = await _createProviders(hasProgress: true);
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      _buildApp(providers: providers, observer: observer),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Architecture of Happiness'));
    await tester.pumpAndSettle();

    expect(observer.pushedRouteNames, contains(RouteNames.reader));
  });
}
