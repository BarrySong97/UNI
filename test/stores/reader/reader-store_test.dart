import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/repositories/book/book-repository-impl.dart';
import 'package:uni/repositories/chapter/chapter-repository-impl.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/repositories/reader-pagination-cache/reader-pagination-cache-repository-impl.dart';
import 'package:uni/repositories/reader-preferences/reader-preferences-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/books-dao.dart';
import 'package:uni/services/db/daos/chapters-dao.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
import 'package:uni/services/db/daos/reader-pagination-cache-dao.dart';
import 'package:uni/services/db/daos/reader-preferences-dao.dart';
import 'package:uni/stores/reader/reader-store.dart';

class _ReaderTestDeps {
  _ReaderTestDeps({
    required this.bookRepository,
    required this.chapterRepository,
    required this.progressRepository,
    required this.readerPaginationCacheRepository,
    required this.readerPreferencesRepository,
  });

  final BookRepositoryImpl bookRepository;
  final ChapterRepositoryImpl chapterRepository;
  final ProgressRepositoryImpl progressRepository;
  final ReaderPaginationCacheRepositoryImpl readerPaginationCacheRepository;
  final ReaderPreferencesRepositoryImpl readerPreferencesRepository;
}

Future<_ReaderTestDeps> _createDeps() async {
  final database = AppDatabase();
  return _ReaderTestDeps(
    bookRepository: BookRepositoryImpl(booksDao: BooksDao(database: database)),
    chapterRepository: ChapterRepositoryImpl(
      chaptersDao: ChaptersDao(database: database),
    ),
    progressRepository: ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    ),
    readerPaginationCacheRepository: ReaderPaginationCacheRepositoryImpl(
      cacheDao: ReaderPaginationCacheDao(database: database),
    ),
    readerPreferencesRepository: ReaderPreferencesRepositoryImpl(
      preferencesDao: ReaderPreferencesDao(database: database),
    ),
  );
}

Future<ReaderStore> _seedBookWithChapters({
  required _ReaderTestDeps deps,
  required String bookId,
  required List<String> chapterContents,
}) async {
  final now = DateTime.now();
  await deps.bookRepository.upsertSeedBook(
    id: bookId,
    title: 'Book $bookId',
    author: 'Author',
    createdAt: now,
    updatedAt: now,
  );

  for (var i = 0; i < chapterContents.length; i++) {
    await deps.chapterRepository.upsertSeedChapter(
      id: '$bookId-chapter-$i',
      bookId: bookId,
      idx: i,
      title: 'Chapter $i',
      content: chapterContents[i],
    );
  }

  return ReaderStore(
    bookRepository: deps.bookRepository,
    chapterRepository: deps.chapterRepository,
    progressRepository: deps.progressRepository,
    readerPaginationCacheRepository: deps.readerPaginationCacheRepository,
    readerPreferencesRepository: deps.readerPreferencesRepository,
  );
}

void main() {
  test('openBook restores chapter and charOffset from progress', () async {
    final deps = await _createDeps();
    final store = await _seedBookWithChapters(
      deps: deps,
      bookId: 'book-1',
      chapterContents: <String>['hello world chapter one'],
    );

    final now = DateTime.now();
    await deps.progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: 'book-1',
        chapterId: 'book-1-chapter-0',
        charOffset: 5,
        percent: 0.25,
        updatedAt: now,
      ),
    );

    await store.openBook('book-1');

    expect(store.state.chapter?.id, 'book-1-chapter-0');
    expect(store.state.currentChapterIndex, 0);
    expect(store.state.charOffset, 5);
    expect(store.state.bookPercent, 0.25);
  });

  test('updateReadingMetrics updates chapter, pages and progress', () async {
    final deps = await _createDeps();
    final store = await _seedBookWithChapters(
      deps: deps,
      bookId: 'book-2',
      chapterContents: <String>['short', 'abcdefghij'],
    );

    await store.openBook('book-2');
    store.updateReadingMetrics(
      chapterIndex: 1,
      chapterCharOffset: 7,
      bookPercent: 0.4,
      currentPage: 3,
      totalPages: 10,
    );

    expect(store.state.chapter?.id, 'book-2-chapter-1');
    expect(store.state.currentChapterIndex, 1);
    expect(store.state.charOffset, 7);
    expect(store.state.bookPercent, 0.4);
    expect(store.state.currentPage, 3);
    expect(store.state.totalPages, 10);
  });

  test('updateReadingMetrics clamps out-of-range input', () async {
    final deps = await _createDeps();
    final store = await _seedBookWithChapters(
      deps: deps,
      bookId: 'book-3',
      chapterContents: <String>['abc'],
    );

    await store.openBook('book-3');
    store.updateReadingMetrics(
      chapterIndex: 99,
      chapterCharOffset: 999,
      bookPercent: 1.8,
      currentPage: -1,
      totalPages: 0,
    );

    expect(store.state.currentChapterIndex, 0);
    expect(store.state.charOffset, 3);
    expect(store.state.bookPercent, 1.0);
    expect(store.state.currentPage, 1);
    expect(store.state.totalPages, 1);
  });

  test('flushProgress forces save immediately', () async {
    final deps = await _createDeps();
    final store = await _seedBookWithChapters(
      deps: deps,
      bookId: 'book-4',
      chapterContents: <String>['abcdefg'],
    );

    await store.openBook('book-4');
    store.updateOffset(4);
    await store.flushProgress();

    final saved = await deps.progressRepository.getProgress('book-4');
    expect(saved?.charOffset, 4);
  });

  test('flushProgress can save silently without emitting listeners', () async {
    final deps = await _createDeps();
    final store = await _seedBookWithChapters(
      deps: deps,
      bookId: 'book-5',
      chapterContents: <String>['abcdefghijk'],
    );

    var notifyCount = 0;
    store.addListener(() {
      notifyCount++;
    });

    await store.openBook('book-5');
    store.updateOffset(6);
    notifyCount = 0;

    await store.flushProgress(emitStateChanges: false);

    final saved = await deps.progressRepository.getProgress('book-5');
    expect(saved?.charOffset, 6);
    expect(notifyCount, 0);
  });

  test('updatePreferences persists per book', () async {
    final deps = await _createDeps();
    final store = await _seedBookWithChapters(
      deps: deps,
      bookId: 'book-6',
      chapterContents: <String>['abcdefghijklmno'],
    );

    await store.openBook('book-6');
    await store.updatePreferences(
      (current) => current.copyWith(
        fontSize: 22,
        backgroundColor: const Color(0xFFEAEFF6),
      ),
    );

    final reloaded = ReaderStore(
      bookRepository: deps.bookRepository,
      chapterRepository: deps.chapterRepository,
      progressRepository: deps.progressRepository,
      readerPaginationCacheRepository: deps.readerPaginationCacheRepository,
      readerPreferencesRepository: deps.readerPreferencesRepository,
    );
    await reloaded.openBook('book-6');

    expect(reloaded.state.preferences?.fontSize, 22);
    expect(
      reloaded.state.preferences?.backgroundColor.toARGB32(),
      const Color(0xFFEAEFF6).toARGB32(),
    );
  });

  test('rebuildPagination and jumpToPage update reading metrics', () async {
    final deps = await _createDeps();
    final store = await _seedBookWithChapters(
      deps: deps,
      bookId: 'book-7',
      chapterContents: <String>['Alpha content. ' * 80, 'Beta content. ' * 80],
    );
    await store.openBook('book-7');

    store.rebuildPagination(
      layoutKey: '390_844_19',
      viewport: const Size(390, 844),
      textStyle: const TextStyle(fontSize: 19, height: 1.7),
      horizontalPadding: 20,
      verticalPadding: 96,
    );
    expect(store.state.pageSlices, isNotEmpty);

    store.jumpToPage(store.state.pageSlices.length - 1);
    expect(store.state.currentPage, store.state.totalPages);
    expect(store.state.currentPageIndex, store.state.totalPages - 1);
  });

  test('restoreWindowFromCache reuses persisted precise slices', () async {
    final deps = await _createDeps();
    final store = await _seedBookWithChapters(
      deps: deps,
      bookId: 'book-8',
      chapterContents: <String>['Alpha content. ' * 70, 'Beta content. ' * 70],
    );
    await store.openBook('book-8');

    const layoutKey = 'layout-cache-key-1';
    store.rebuildPagination(
      layoutKey: layoutKey,
      viewport: const Size(390, 844),
      textStyle: const TextStyle(fontSize: 19, height: 1.7),
      horizontalPadding: 20,
      verticalPadding: 96,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final reloaded = ReaderStore(
      bookRepository: deps.bookRepository,
      chapterRepository: deps.chapterRepository,
      progressRepository: deps.progressRepository,
      readerPaginationCacheRepository: deps.readerPaginationCacheRepository,
      readerPreferencesRepository: deps.readerPreferencesRepository,
    );
    await reloaded.openBook('book-8');
    final restored = await reloaded.restoreWindowFromCache(
      layoutKey: layoutKey,
      chapterStart: 0,
      chapterEnd: 1,
    );

    expect(restored, isTrue);
    expect(reloaded.state.pageSlices, isNotEmpty);
    expect(reloaded.state.paginationSource, 'cache');
  });

  test('ensureCatalogMetricsReady transitions loading to ready', () async {
    final deps = await _createDeps();
    final store = await _seedBookWithChapters(
      deps: deps,
      bookId: 'book-9',
      chapterContents: <String>['Alpha content. ' * 70, 'Beta content. ' * 70],
    );
    await store.openBook('book-9');
    store.rebuildPagination(
      layoutKey: 'catalog-layout-1',
      viewport: const Size(390, 844),
      textStyle: const TextStyle(fontSize: 19, height: 1.7),
      horizontalPadding: 20,
      verticalPadding: 96,
    );

    final statuses = <String>[];
    store.addListener(() {
      statuses.add(store.state.catalogMetricsStatus);
    });

    await store.ensureCatalogMetricsReady();

    expect(statuses, contains('loading'));
    expect(store.state.catalogMetricsStatus, 'ready');
    expect(store.state.catalogChapterStartPages, isNotEmpty);
    expect(store.state.catalogTotalPages, greaterThan(0));
  });

  test('catalog metrics are invalidated when layout changes', () async {
    final deps = await _createDeps();
    final store = await _seedBookWithChapters(
      deps: deps,
      bookId: 'book-10',
      chapterContents: <String>['Alpha content. ' * 60, 'Beta content. ' * 60],
    );
    await store.openBook('book-10');
    store.rebuildPagination(
      layoutKey: 'catalog-layout-2',
      viewport: const Size(390, 844),
      textStyle: const TextStyle(fontSize: 19, height: 1.7),
      horizontalPadding: 20,
      verticalPadding: 96,
    );
    await store.ensureCatalogMetricsReady();
    expect(store.state.catalogMetricsStatus, 'ready');

    store.rebuildPagination(
      layoutKey: 'catalog-layout-3',
      viewport: const Size(390, 844),
      textStyle: const TextStyle(fontSize: 21, height: 1.7),
      horizontalPadding: 20,
      verticalPadding: 96,
    );
    expect(store.state.catalogMetricsStatus, 'idle');

    await store.ensureCatalogMetricsReady();
    expect(store.state.catalogMetricsStatus, 'ready');
  });
}
