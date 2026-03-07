import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/app/i18n/app-locale.dart';
import 'package:uni/app/i18n/app-localizations.dart';
import 'package:uni/app/providers/app-providers.dart';
import 'package:uni/app/routes/route-names.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/pages/library/book-detail-page.dart';
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
import 'package:uni/services/library/book-profile-color-service.dart';
import 'package:uni/services/library/book-profile-entry-service.dart';
import 'package:uni/services/parser/book-import-service.dart';
import 'package:uni/stores/highlight/highlight-store.dart';
import 'package:uni/stores/library/library-store.dart';
import 'package:uni/stores/reader/reader-store.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = <String?>[];
  final List<String?> replacedRouteNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacedRouteNames.add(newRoute?.settings.name);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

Future<AppProviders> _createProviders({
  bool secondBookHasProgress = false,
  String? mainBookProfileBgColor,
  String mainBookAuthor = 'Alain de Botton',
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
      author: mainBookAuthor,
      sourceType: 'local_epub',
      profileBgColor: mainBookProfileBgColor,
      epubFilePath: '/tmp/book-1.epub',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await bookRepository.upsertBook(
    BookEntity(
      id: 'book-2',
      title: 'Thinking Architecture',
      author: 'Peter Zumthor',
      sourceType: 'local_epub',
      epubFilePath: '/tmp/book-2.epub',
      createdAt: now,
      updatedAt: now,
    ),
  );

  if (secondBookHasProgress) {
    await progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: 'book-2',
        locatorJson: '{"href":"/chapter1.xhtml","type":"text/html"}',
        percent: 0.5,
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

void main() {
  testWidgets('BookDetailPage renders book profile with title and stats', (tester) async {
    final providers = await _createProviders(
      mainBookProfileBgColor: '#FFCC3344',
    );

    await tester.pumpWidget(
      AppProvidersScope(
        providers: providers,
        child: MaterialApp(
          supportedLocales: AppLocaleController.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          home: const BookDetailPage(bookId: 'book-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Architecture of Happiness'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Words'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Fiction'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);

    final gradientFinder = find.byWidgetPredicate((widget) {
      if (widget is! Container) {
        return false;
      }
      final decoration = widget.decoration;
      return decoration is BoxDecoration && decoration.gradient != null;
    });
    expect(gradientFinder, findsAtLeastNWidgets(1));
    final gradientContainer = tester.widget<Container>(gradientFinder.first);
    final gradient =
        (gradientContainer.decoration! as BoxDecoration).gradient
            as LinearGradient;
    final expected = const BookProfileColorService().gradientFromStoredHex(
      '#FFCC3344',
    );
    expect(gradient.colors.first.toARGB32(), expected.colors.first.toARGB32());

    final overlayFinder = find.byWidgetPredicate(
      (widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
    );
    expect(overlayFinder, findsAtLeastNWidgets(1));
    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      overlayFinder.first,
    );
    expect(
      overlay.value.statusBarColor?.toARGB32(),
      Colors.transparent.toARGB32(),
    );
  });

  testWidgets('does not render unknown author text', (tester) async {
    final providers = await _createProviders(mainBookAuthor: 'Unknown');

    await tester.pumpWidget(
      AppProvidersScope(
        providers: providers,
        child: MaterialApp(
          supportedLocales: AppLocaleController.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          home: const BookDetailPage(bookId: 'book-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unknown'), findsNothing);
  });

  testWidgets('Continue navigates to reader route', (tester) async {
    final providers = await _createProviders();
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      AppProvidersScope(
        providers: providers,
        child: MaterialApp(
          supportedLocales: AppLocaleController.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          navigatorObservers: <NavigatorObserver>[observer],
          routes: <String, WidgetBuilder>{
            RouteNames.reader: (_) => const Scaffold(body: Text('reader')),
          },
          home: const BookDetailPage(bookId: 'book-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(observer.pushedRouteNames, contains(RouteNames.reader));
  });

  testWidgets('settings menu can delete book and navigate to main tabs', (
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
            if (settings.name == RouteNames.mainTabs) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('main-tabs')),
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
          home: const BookDetailPage(bookId: 'book-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete book'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(observer.pushedRouteNames, contains(RouteNames.mainTabs));
    expect(await providers.bookRepository.getBookById('book-1'), isNull);
  });
}
