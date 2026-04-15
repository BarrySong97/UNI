import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/app/i18n/app-locale.dart';
import 'package:uni/app/providers/app-providers.dart';
import 'package:uni/entities/annotation-entity.dart';
import 'package:uni/entities/book-entity.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/pages/reader/reader_coordinate_helper.dart';
import 'package:uni/pages/reader/reader_page.dart';
import 'package:uni/repositories/annotation/annotation-repository-impl.dart';
import 'package:uni/repositories/book/book-repository-impl.dart';
import 'package:uni/repositories/chapter/chapter-repository-impl.dart';
import 'package:uni/repositories/highlight/highlight-repository-impl.dart';
import 'package:uni/repositories/progress/progress-repository.dart';
import 'package:uni/services/ai/ai_settings_service.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/annotation-notes-dao.dart';
import 'package:uni/services/db/daos/annotations-dao.dart';
import 'package:uni/services/db/daos/books-dao.dart';
import 'package:uni/services/db/daos/chapters-dao.dart';
import 'package:uni/services/db/daos/highlights-dao.dart';
import 'package:uni/services/library/book-profile-entry-service.dart';
import 'package:uni/services/parser/book-import-service.dart';
import 'package:uni/services/phonetics/phonetics_service.dart';
import 'package:uni/services/reader/annotation/annotation_models.dart';
import 'package:uni/services/reader/annotation/annotation_projection.dart';
import 'package:uni/services/reader/annotation/annotation_text_utils.dart';
import 'package:uni/services/reader/annotation/reader_annotation_resolver.dart';
import 'package:uni/services/reader/data/chapter_data_source.dart';
import 'package:uni/services/reader/epub_preparse_service.dart';
import 'package:uni/services/reader/models/parsed_chapter.dart';
import 'package:uni/services/reader/models/render_node.dart';
import 'package:uni/services/reader/selection/page_hit_test.dart';
import 'package:uni/services/tts/tts_service.dart';
import 'package:uni/stores/annotation/annotation-store.dart';
import 'package:uni/stores/highlight/highlight-store.dart';
import 'package:uni/stores/library/library-store.dart';
import 'package:uni/stores/reader/reader_store.dart';

class _FakeProgressRepository implements ProgressRepository {
  _FakeProgressRepository();

  ReadingProgressEntity? lastSaved;

  @override
  Future<List<ReadingProgressEntity>> getAllProgress() async {
    return lastSaved == null ? const [] : <ReadingProgressEntity>[lastSaved!];
  }

  @override
  Future<ReadingProgressEntity?> getProgress(String bookId) async {
    if (lastSaved != null && lastSaved!.bookId == bookId) {
      return lastSaved;
    }
    return null;
  }

  @override
  Future<void> saveProgress(ReadingProgressEntity progress) async {
    lastSaved = progress;
  }
}

class _FakeChapterDataSource implements ChapterDataSource {
  const _FakeChapterDataSource({required this.book, required this.chapters});

  final ParsedBook book;
  final List<ParsedChapter> chapters;

  @override
  Future<ParsedChapter> loadChapter(int chapterIndex) async {
    return chapters[chapterIndex];
  }

  @override
  Future<ParsedBook> loadBook() async => book;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('keyboard padding changes do not move page indicator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase();
    final progressRepository = _FakeProgressRepository();
    final providers = _buildProviders(
      database: database,
      progressRepository: progressRepository,
    );

    final book = _bookEntity();
    final chapter = _chapter(
      index: 0,
      title: 'Chapter 1',
      href: 'Text/ch0.xhtml',
      text: _longText(260),
    );
    final dataSource = _FakeChapterDataSource(
      book: ParsedBook(
        metadata: const BookMetadata(title: 'T', author: 'A'),
        toc: const <TocEntry>[
          TocEntry(title: 'Chapter 1', href: 'Text/ch0.xhtml'),
        ],
        chapters: <ParsedChapter>[chapter],
      ),
      chapters: <ParsedChapter>[chapter],
    );

    Widget buildApp(MediaQueryData mediaQueryData) {
      return MediaQuery(
        data: mediaQueryData,
        child: MaterialApp(
          home: AppProvidersScope(
            providers: providers,
            child: ReaderPage(
              book: book,
              dataSource: dataSource,
              storeManager: providers.readerStoreManager,
            ),
          ),
        ),
      );
    }

    const stableViewPadding = EdgeInsets.only(bottom: 34);
    await tester.pumpWidget(
      buildApp(
        const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: 34),
          viewPadding: stableViewPadding,
        ),
      ),
    );

    final store = providers.readerStoreManager.getStore(book.id);
    await _waitForReaderReady(store);
    await tester.pumpAndSettle();

    final pageIndicatorFinder = find.text(
      '${store.currentPageIndex + 1} / ${store.totalPagesInChapter}',
    );
    expect(pageIndicatorFinder, findsOneWidget);
    final beforeOffset = tester.getBottomLeft(pageIndicatorFinder);

    await tester.pumpWidget(
      buildApp(
        const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.zero,
          viewPadding: stableViewPadding,
          viewInsets: EdgeInsets.only(bottom: 320),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final afterOffset = tester.getBottomLeft(pageIndicatorFinder);
    expect(afterOffset.dy, beforeOffset.dy);

    await store.flushProgress();
    providers.readerStoreManager.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
  });

  testWidgets('adding a note from a focused mark does not trigger page turn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase();
    final progressRepository = _FakeProgressRepository();
    final providers = _buildProviders(
      database: database,
      progressRepository: progressRepository,
    );

    final annotationStore = providers.annotationStore;
    final book = _bookEntity();
    final chapter = _chapter(
      index: 0,
      title: 'Chapter 1',
      href: 'Text/ch0.xhtml',
      text: _longText(260),
    );
    final dataSource = _FakeChapterDataSource(
      book: ParsedBook(
        metadata: const BookMetadata(title: 'T', author: 'A'),
        toc: const <TocEntry>[
          TocEntry(title: 'Chapter 1', href: 'Text/ch0.xhtml'),
        ],
        chapters: <ParsedChapter>[chapter],
      ),
      chapters: <ParsedChapter>[chapter],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppProvidersScope(
          providers: providers,
          child: ReaderPage(
            book: book,
            dataSource: dataSource,
            storeManager: providers.readerStoreManager,
          ),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.resizeToAvoidBottomInset, isFalse);

    final store = providers.readerStoreManager.getStore(book.id);
    await _waitForReaderReady(store);

    expect(store.totalPagesInChapter, greaterThan(2));

    store.nextPage();
    await tester.pumpAndSettle();

    final pageIndexBefore = store.currentPageIndex;
    final annotation = _buildAnnotationForCurrentPage(
      store: store,
      bookId: book.id,
    );
    await annotationStore.createMark(
      bookId: book.id,
      quoteText: annotation.quoteText,
      anchor: AnnotationAnchorV1.tryParse(annotation.anchorJson)!,
      color: annotation.color,
      style: annotation.style,
    );
    await tester.pumpAndSettle();

    final annotationTapOffset = _annotationTapOffsetForCurrentPage(store);
    await tester.tapAt(annotationTapOffset);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reader-tooltip-note')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reader-tooltip-note')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-composer-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('selection-note-sheet')), findsNothing);
    expect(store.currentPageIndex, pageIndexBefore);

    await tester.enterText(
      find.byKey(const ValueKey('note-composer-input')),
      'A stable note',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('note-composer-publish')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-composer-input')), findsNothing);
    expect(store.currentPageIndex, pageIndexBefore);
    expect(
      annotationStore.state.notesByAnnotationId.values.expand((item) => item),
      isNotEmpty,
    );

    await store.flushProgress();
    await tester.pumpWidget(const SizedBox.shrink());
    providers.readerStoreManager.dispose();
    await tester.pump();
  });
}

AppProviders _buildProviders({
  required AppDatabase database,
  required _FakeProgressRepository progressRepository,
}) {
  final bookRepository = BookRepositoryImpl(
    booksDao: BooksDao(database: database),
  );
  final chapterRepository = ChapterRepositoryImpl(
    chaptersDao: ChaptersDao(database: database),
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

Future<void> _waitForReaderReady(ReaderStore store) async {
  final sw = Stopwatch()..start();
  while (store.currentPageLayout == null || store.totalPagesInChapter <= 1) {
    if (sw.elapsedMilliseconds > 5000) {
      fail('Timed out waiting for reader page to load');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

AnnotationEntity _buildAnnotationForCurrentPage({
  required ReaderStore store,
  required String bookId,
}) {
  final page = store.currentPageLayout;
  final pagination = store.currentChapterPagination;
  if (page == null || pagination == null) {
    throw StateError('Reader page not ready');
  }

  final projections = buildChapterBlockProjections(pagination);
  for (
    var elementIndex = 0;
    elementIndex < page.elements.length;
    elementIndex++
  ) {
    final element = page.elements[elementIndex];
    final text = layoutElementPlainText(element).trim();
    if (text.isEmpty) {
      continue;
    }
    final blockIndex = renderNodeBlockIndex(element.sourceNode);
    if (blockIndex == null) {
      continue;
    }
    final projection = projections[blockIndex];
    if (projection == null) {
      continue;
    }
    final slice = findBlockSlice(
      projection,
      page.pageIndexInChapter,
      elementIndex,
    );
    if (slice == null || slice.startOffset >= slice.endOffset) {
      continue;
    }

    final rawText = projection.rawText;
    final quoteText = rawText.substring(slice.startOffset, slice.endOffset);
    final now = DateTime(2024, 1, 1);
    final anchor = AnnotationAnchorV1(
      parserVersion: 3,
      segments: <AnnotationAnchorSegment>[
        AnnotationAnchorSegment(
          chapterIndex: page.chapterIndex,
          chapterHref: _chapterHrefForPage(page.chapterIndex),
          blockIndex: blockIndex,
          startOffset: slice.startOffset,
          endOffset: slice.endOffset,
          quoteText: quoteText,
          prefixText: rawText.substring(0, slice.startOffset),
          suffixText: rawText.substring(slice.endOffset),
          blockTextHash: hashNormalizedText(rawText),
        ),
      ],
      jumpTarget: AnnotationJumpTarget(
        chapterIndex: page.chapterIndex,
        chapterHref: _chapterHrefForPage(page.chapterIndex),
        blockIndex: blockIndex,
        offset: slice.startOffset,
      ),
    );

    return AnnotationEntity(
      id: 'ann-current-page',
      bookId: bookId,
      kind: AnnotationKind.mark,
      style: AnnotationStyle.highlight,
      quoteText: quoteText,
      anchorJson: anchor.encode(),
      color: '#FFE082',
      createdAt: now,
      updatedAt: now,
    );
  }

  throw StateError('Failed to find a text element on the current page');
}

Offset _annotationTapOffsetForCurrentPage(ReaderStore store) {
  final page = store.currentPageLayout;
  final pagination = store.currentChapterPagination;
  if (page == null || pagination == null) {
    throw StateError('Reader page not ready');
  }

  final annotation = _buildAnnotationForCurrentPage(
    store: store,
    bookId: 'book-1',
  );
  final resolved = const ReaderAnnotationResolver().resolveChapterAnnotations(
    pagination: pagination,
    annotations: <AnnotationEntity>[annotation],
  );
  if (resolved.isEmpty) {
    throw StateError('Failed to resolve annotation rects');
  }

  final rects = getSelectionRects(page, resolved.first.pageSelection);
  if (rects.isEmpty) {
    throw StateError('Failed to resolve annotation hit area');
  }

  final helper = SinglePageCoordinateHelper(
    horizontalPadding: store.preferences.pageHorizontalPaddingPx,
    verticalPadding: store.preferences.pageVerticalPaddingPx,
    safeAreaTop: 0,
  );
  return helper.toScreenOffset(rects.first.center);
}

ParsedChapter _chapter({
  required int index,
  required String title,
  required String href,
  required String text,
}) {
  return ParsedChapter(
    index: index,
    title: title,
    href: href,
    nodes: <RenderNode>[
      ParagraphNode(
        blockIndex: 1,
        children: <RenderNode>[TextNode(content: text)],
      ),
    ],
  );
}

BookEntity _bookEntity() {
  final now = DateTime(2024, 1, 1);
  return BookEntity(
    id: 'book-1',
    title: 'Test Book',
    author: 'Test Author',
    sourceType: 'local_epub',
    createdAt: now,
    updatedAt: now,
  );
}

String _longText(int repeat) {
  return List<String>.filled(
    repeat,
    'This is a long paragraph used to force pagination across multiple pages.',
  ).join(' ');
}

String _chapterHrefForPage(int chapterIndex) {
  return 'Text/ch$chapterIndex.xhtml';
}
