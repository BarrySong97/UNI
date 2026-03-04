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
  final List<Route<dynamic>> pushedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

Future<AppProviders> _createProviders(List<ChapterEntity> chapters) async {
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
      title: 'Reader Book',
      author: 'Author',
      sourceType: 'local_epub',
      createdAt: now,
      updatedAt: now,
    ),
  );

  for (final chapter in chapters) {
    await chapterRepository.upsertChapter(chapter);
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

Widget _buildReaderTestApp({
  required AppProviders providers,
  required _RecordingNavigatorObserver observer,
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
            builder: (_) => const Scaffold(body: Text('book-profile')),
          );
        }
        return null;
      },
      home: const ReaderPage(bookId: 'book-1'),
    ),
  );
}

void main() {
  testWidgets('ReaderPage shows page indicator and hides chrome by default', (
    tester,
  ) async {
    final providers = await _createProviders(<ChapterEntity>[
      ChapterEntity(
        id: 'book-1-c1',
        bookId: 'book-1',
        idx: 0,
        title: 'Chapter 1',
        content: 'Chapter one content. ' * 30,
        wordCount: 600,
      ),
    ]);
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      _buildReaderTestApp(providers: providers, observer: observer),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('/'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert).hitTestable(), findsNothing);
  });

  testWidgets('ReaderPage toggles chrome and opens more sheet', (tester) async {
    final providers = await _createProviders(<ChapterEntity>[
      ChapterEntity(
        id: 'book-1-c1',
        bookId: 'book-1',
        idx: 0,
        title: 'Chapter 1',
        content: 'Chapter one content. ' * 30,
        wordCount: 600,
      ),
    ]);
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      _buildReaderTestApp(providers: providers, observer: observer),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SelectableText).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert).hitTestable(), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Reader Book'), findsOneWidget);
    expect(find.text('Download done'), findsOneWidget);
  });

  testWidgets('ReaderPage opens chapter panel from bottom bar', (tester) async {
    final providers = await _createProviders(<ChapterEntity>[
      ChapterEntity(
        id: 'book-1-c1',
        bookId: 'book-1',
        idx: 0,
        title: 'Chapter 1',
        content: 'Alpha content. ' * 60,
        wordCount: 560,
      ),
      ChapterEntity(
        id: 'book-1-c2',
        bookId: 'book-1',
        idx: 1,
        title: 'Chapter 2',
        content: 'Beta content. ' * 60,
        wordCount: 520,
      ),
    ]);

    await tester.pumpWidget(
      _buildReaderTestApp(
        providers: providers,
        observer: _RecordingNavigatorObserver(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SelectableText).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu).hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('Search this book'), findsOneWidget);
    expect(find.text('Add bookmark'), findsNothing);
    expect(find.text('Chapter 1'), findsWidgets);
    expect(find.text('Chapter 2'), findsOneWidget);
    // With math pagination, catalog metrics are ready immediately:
    // chapter page numbers are shown directly, no '--' loading state.
    expect(find.text('--'), findsNothing);

    final progressTexts = tester
        .widgetList<Text>(find.byType(Text))
        .where(
          (text) =>
              text.data != null && text.data!.startsWith('Current reading '),
        )
        .toList(growable: false);
    expect(progressTexts, hasLength(1));
    expect(
      progressTexts.first.data,
      matches(RegExp(r'^Current reading \d+/\d+$')),
    );

    final chapterOneTexts = tester.widgetList<Text>(find.text('Chapter 1'));
    final hasHighlightedChapterTitle = chapterOneTexts.any(
      (text) =>
          text.style?.fontWeight == FontWeight.w700 &&
          text.style?.color == const Color(0xFF1685FF),
    );
    expect(hasHighlightedChapterTitle, isTrue);
  });
}
