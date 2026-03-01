import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/app/i18n/app-locale.dart';
import 'package:uni/app/i18n/app-localizations.dart';
import 'package:uni/app/providers/app-providers.dart';
import 'package:uni/app/routes/route-names.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/entities/chapter-entity.dart';
import 'package:uni/pages/reader/reader-page.dart';
import 'package:uni/repositories/book/book-repository-impl.dart';
import 'package:uni/repositories/chapter/chapter-repository-impl.dart';
import 'package:uni/repositories/highlight/highlight-repository-impl.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/books-dao.dart';
import 'package:uni/services/db/daos/chapters-dao.dart';
import 'package:uni/services/db/daos/highlights-dao.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
import 'package:uni/services/library/book-profile-entry-service.dart';
import 'package:uni/services/parser/book-import-service.dart';
import 'package:uni/stores/highlight/highlight-store.dart';
import 'package:uni/stores/library/library-store.dart';
import 'package:uni/stores/reader/reader-store.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

Future<AppProviders> _createProviders() async {
  final database = AppDatabase();
  final booksDao = BooksDao(database: database);
  final chaptersDao = ChaptersDao(database: database);
  final progressDao = ProgressDao(database: database);
  final highlightsDao = HighlightsDao(database: database);

  final bookRepository = BookRepositoryImpl(booksDao: booksDao);
  final chapterRepository = ChapterRepositoryImpl(chaptersDao: chaptersDao);
  final progressRepository = ProgressRepositoryImpl(progressDao: progressDao);
  final highlightRepository = HighlightRepositoryImpl(
    highlightsDao: highlightsDao,
  );

  final now = DateTime.now();
  await bookRepository.upsertBook(
    BookEntity(
      id: 'book-1',
      title: 'Reader Book',
      author: 'Author',
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
      content: 'Chapter text for reader page test.',
      wordCount: 33,
    ),
  );

  final providers = AppProviders(
    bookRepository: bookRepository,
    chapterRepository: chapterRepository,
    progressRepository: progressRepository,
    highlightRepository: highlightRepository,
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
    ),
    highlightStore: HighlightStore(highlightRepository: highlightRepository),
  );
  return providers;
}

void main() {
  testWidgets('ReaderPage opens Book Profile from toolbar button', (
    tester,
  ) async {
    final providers = await _createProviders();
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      AppProvidersScope(
        providers: providers,
        child: MaterialApp(
          supportedLocales: AppLocaleController.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          navigatorObservers: <NavigatorObserver>[observer],
          onGenerateRoute: (settings) {
            if (settings.name == RouteNames.bookDetail) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('book-profile')),
              );
            }
            return null;
          },
          home: const ReaderPage(bookId: 'book-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await tester.pumpAndSettle();

    final matchedRoutes = observer.pushedRoutes.where(
      (route) => route.settings.name == RouteNames.bookDetail,
    );
    expect(matchedRoutes, isNotEmpty);
    expect(matchedRoutes.last.settings.arguments, 'book-1');
  });
}
