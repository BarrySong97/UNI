import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/app/i18n/app-locale.dart';
import 'package:uni/app/i18n/app-localizations.dart';
import 'package:uni/app/providers/app-providers.dart';
import 'package:uni/app/routes/route-names.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/entities/reading-progress-entity.dart';
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
import 'package:uni/services/reader/reader-overlay-controller.dart';
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

class _FakeReaderOverlayController extends ReaderOverlayController {
  _FakeReaderOverlayController({required this.canOpenInstantly});

  final bool canOpenInstantly;
  int showCallCount = 0;

  @override
  bool canShowInstantly(String bookId) => canOpenInstantly;

  @override
  void show([String? bookId]) {
    showCallCount += 1;
  }
}

Future<AppProviders> _createProviders({
  required bool hasProgress,
  ReaderOverlayController? readerOverlayController,
}) async {
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
    bookProfileEntryService: const BookProfileEntryService(),
    appLocaleController: AppLocaleController(),
    readerOverlayController: readerOverlayController,
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
  testWidgets(
    'book with progress falls back to reader route when not preloaded',
    (tester) async {
      final providers = await _createProviders(hasProgress: true);
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        _buildApp(providers: providers, observer: observer),
      );
      await tester.pumpAndSettle();

      final bookTitleFinder = find.text('Architecture of Happiness').last;
      await tester.ensureVisible(bookTitleFinder);
      await tester.tap(bookTitleFinder);
      await tester.pumpAndSettle();

      expect(observer.pushedRouteNames, contains(RouteNames.reader));
    },
  );

  testWidgets('book with progress shows overlay when preloaded matches', (
    tester,
  ) async {
    final overlayController = _FakeReaderOverlayController(
      canOpenInstantly: true,
    );
    final providers = await _createProviders(
      hasProgress: true,
      readerOverlayController: overlayController,
    );
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      _buildApp(providers: providers, observer: observer),
    );
    await tester.pumpAndSettle();

    final bookTitleFinder = find.text('Architecture of Happiness').last;
    await tester.ensureVisible(bookTitleFinder);
    await tester.tap(bookTitleFinder);
    await tester.pumpAndSettle();

    expect(overlayController.showCallCount, 1);
    expect(observer.pushedRouteNames, isNot(contains(RouteNames.reader)));
  });
}
