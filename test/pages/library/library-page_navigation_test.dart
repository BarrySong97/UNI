import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/app/i18n/app-locale.dart';
import 'package:uni/app/i18n/app-localizations.dart';
import 'package:uni/app/providers/app-providers.dart';
import 'package:uni/app/routes/route-names.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/components/library/library-book-tile.dart';
import 'package:uni/pages/library/library-page.dart';
import 'package:uni/repositories/book/book-repository-impl.dart';
import 'package:uni/repositories/chapter/chapter-repository-impl.dart';
import 'package:uni/repositories/highlight/highlight-repository-impl.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/repositories/reader-preferences/reader-preferences-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/books-dao.dart';
import 'package:uni/services/db/daos/chapters-dao.dart';
import 'package:uni/services/db/daos/highlights-dao.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
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

  final now = DateTime.now();
  await bookRepository.upsertBook(
    BookEntity(
      id: 'book-1',
      title: 'Architecture of Happiness',
      author: 'Alain de Botton',
      sourceType: 'local_epub',
      epubFilePath: '/tmp/book-1.epub',
      createdAt: now,
      updatedAt: now,
    ),
  );
  if (hasProgress) {
    await progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: 'book-1',
        locatorJson: '{"href":"/chapter1.xhtml","type":"text/html"}',
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
    readerPreferencesRepository: readerPreferencesRepository,
    bookProfileEntryService: BookProfileEntryService(
      progressRepository: progressRepository,
    ),
    appLocaleController: AppLocaleController(),
  );
  providers.registerStores(
    libraryStore: LibraryStore(
      bookRepository: bookRepository,
      bookImportService: BookImportService(),
      booksDirectory: '/tmp/test_books',
      progressRepository: progressRepository,
    ),
    readerStore: ReaderStore(
      bookRepository: bookRepository,
      progressRepository: progressRepository,
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

    // Book without progress appears in the grid — scroll down to it and tap
    final tileFinder = find.byType(LibraryBookTile);
    expect(tileFinder, findsOneWidget);
    await tester.ensureVisible(tileFinder);
    await tester.pumpAndSettle();
    await tester.tap(tileFinder);
    await tester.pumpAndSettle();

    expect(observer.pushedRouteNames, contains(RouteNames.bookDetail));
  });

  testWidgets('book with progress routes to reader via Continue button', (tester) async {
    final providers = await _createProviders(hasProgress: true);
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      _buildApp(providers: providers, observer: observer),
    );
    await tester.pumpAndSettle();

    // Book with progress appears in NowReadingCard — tap Continue button
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(observer.pushedRouteNames, contains(RouteNames.reader));
  });
}
