import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/app/i18n/app-locale.dart';
import 'package:uni/app/providers/app-providers.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/pages/library/library-page.dart';
import 'package:uni/repositories/annotation/annotation-repository-impl.dart';
import 'package:uni/repositories/book/book-repository-impl.dart';
import 'package:uni/repositories/chapter/chapter-repository-impl.dart';
import 'package:uni/repositories/highlight/highlight-repository-impl.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/services/ai/ai_settings_service.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/annotation-notes-dao.dart';
import 'package:uni/services/db/daos/annotations-dao.dart';
import 'package:uni/services/db/daos/books-dao.dart';
import 'package:uni/services/db/daos/chapters-dao.dart';
import 'package:uni/services/db/daos/highlights-dao.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
import 'package:uni/services/library/book-profile-entry-service.dart';
import 'package:uni/services/parser/book-import-service.dart';
import 'package:uni/services/phonetics/phonetics_service.dart';
import 'package:uni/services/pos/pos_service.dart';
import 'package:uni/services/reader/epub_preparse_service.dart';
import 'package:uni/services/tts/tts_service.dart';
import 'package:uni/stores/annotation/annotation-store.dart';
import 'package:uni/stores/highlight/highlight-store.dart';
import 'package:uni/stores/library/library-store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('library page groups notes by mark and opens full list page', (
    tester,
  ) async {
    final database = AppDatabase();
    final providers = _buildProviders(database: database);
    final now = DateTime.now();

    await providers.bookRepository.upsertBook(
      BookEntity(
        id: 'b1',
        title: 'Book One',
        author: 'Author One',
        coverUrl:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==',
        sourceType: 'local_epub',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await providers.bookRepository.upsertBook(
      BookEntity(
        id: 'b2',
        title: 'Book Two',
        author: 'Author Two',
        sourceType: 'local_epub',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await providers.annotationRepository.createAnnotation(
      AnnotationEntity(
        id: 'a1',
        bookId: 'b1',
        kind: AnnotationKind.mark,
        style: AnnotationStyle.highlight,
        quoteText: 'A line worth keeping',
        anchorJson:
            '{"version":1,"parserVersion":3,"segments":[],"jumpTarget":{"chapterIndex":0,"chapterHref":"Text/ch0.xhtml","blockIndex":1,"offset":0}}',
        color: '#FFE082',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await providers.annotationRepository.createNote(
      annotationId: 'a1',
      bookId: 'b1',
      text: 'First note.',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await providers.annotationRepository.createNote(
      annotationId: 'a1',
      bookId: 'b1',
      text: 'Second note.',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await providers.annotationRepository.createNote(
      annotationId: 'a1',
      bookId: 'b1',
      text: 'Third note.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppProvidersScope(
            providers: providers,
            child: const LibraryPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('library-content-tabs')), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Book One'), findsWidgets);

    await tester.tap(find.text('Notes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('library-note-card-a1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('library-note-book-cover-b1')),
      findsOneWidget,
    );
    expect(find.text('First note.'), findsNothing);
    expect(find.text('Second note.'), findsNothing);
    expect(find.text('Third note.'), findsOneWidget);
    expect(find.textContaining('A line worth keeping'), findsOneWidget);
    expect(find.text('Go to Position'), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);
    expect(find.text('Me'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('library-note-view-all-a1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('All Notes'), findsOneWidget);
    expect(find.text('First note.'), findsOneWidget);
    expect(find.text('Second note.'), findsWidgets);
    expect(find.text('Third note.'), findsWidgets);
    expect(
      find.byKey(const ValueKey('library-note-detail-card-a1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('library-note-detail-go-to-a1')),
      findsOneWidget,
    );
  });
}

AppProviders _buildProviders({required AppDatabase database}) {
  final bookRepository = BookRepositoryImpl(
    booksDao: BooksDao(database: database),
  );
  final chapterRepository = ChapterRepositoryImpl(
    chaptersDao: ChaptersDao(database: database),
  );
  final progressRepository = ProgressRepositoryImpl(
    progressDao: ProgressDao(database: database),
  );
  final annotationRepository = AnnotationRepositoryImpl(
    annotationsDao: AnnotationsDao(database: database),
    annotationNotesDao: AnnotationNotesDao(database: database),
  );
  final highlightRepository = HighlightRepositoryImpl(
    highlightsDao: HighlightsDao(database: database),
  );

  final providers = AppProviders(
    bookRepository: bookRepository,
    chapterRepository: chapterRepository,
    progressRepository: progressRepository,
    annotationRepository: annotationRepository,
    highlightRepository: highlightRepository,
    bookProfileEntryService: const BookProfileEntryService(),
    appLocaleController: AppLocaleController(),
    epubPreparseService: EpubPreparseService(),
    aiSettingsService: AiSettingsService(),
    ttsService: TtsService(),
    phoneticsService: PhoneticsService(),
    posService: PosService(queryOverride: (_) async => null),
    database: database,
  );

  providers.registerStores(
    annotationStore: AnnotationStore(
      annotationRepository: annotationRepository,
    ),
    libraryStore: LibraryStore(
      bookRepository: bookRepository,
      bookImportService: BookImportService(),
      booksDirectory: '',
      progressRepository: progressRepository,
      database: database,
      epubPreparseService: EpubPreparseService(),
    ),
    highlightStore: HighlightStore(highlightRepository: highlightRepository),
  );

  return providers;
}
