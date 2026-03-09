import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/repositories/book/book-repository-impl.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/repositories/reader-preferences/reader-preferences-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/books-dao.dart';
import 'package:uni/services/db/daos/progress-dao.dart';
import 'package:uni/services/db/daos/reader-preferences-dao.dart';
import 'package:uni/stores/reader/reader-store.dart';

class _ReaderTestDeps {
  _ReaderTestDeps({
    required this.bookRepository,
    required this.progressRepository,
    required this.readerPreferencesRepository,
  });

  final BookRepositoryImpl bookRepository;
  final ProgressRepositoryImpl progressRepository;
  final ReaderPreferencesRepositoryImpl readerPreferencesRepository;
}

Future<_ReaderTestDeps> _createDeps() async {
  final database = AppDatabase();
  return _ReaderTestDeps(
    bookRepository: BookRepositoryImpl(booksDao: BooksDao(database: database)),
    progressRepository: ProgressRepositoryImpl(
      progressDao: ProgressDao(database: database),
    ),
    readerPreferencesRepository: ReaderPreferencesRepositoryImpl(
      preferencesDao: ReaderPreferencesDao(database: database),
    ),
  );
}

Future<ReaderStore> _seedBook({
  required _ReaderTestDeps deps,
  required String bookId,
  String epubFilePath = '/tmp/test.epub',
}) async {
  final now = DateTime.now();
  await deps.bookRepository.upsertSeedBook(
    id: bookId,
    title: 'Book $bookId',
    author: 'Author',
    epubFilePath: epubFilePath,
    createdAt: now,
    updatedAt: now,
  );

  return ReaderStore(
    bookRepository: deps.bookRepository,
    progressRepository: deps.progressRepository,
    readerPreferencesRepository: deps.readerPreferencesRepository,
  );
}

void main() {
  test('openBook loads book entity and default preferences', () async {
    final deps = await _createDeps();
    final store = await _seedBook(deps: deps, bookId: 'book-1');

    await store.openBook('book-1');

    expect(store.state.book?.id, 'book-1');
    expect(store.state.book?.title, 'Book book-1');
    expect(store.state.preferences, isNotNull);
    expect(store.state.isLoading, false);
  });

  test('openBook restores locator from saved progress', () async {
    final deps = await _createDeps();
    final store = await _seedBook(deps: deps, bookId: 'book-2');

    const locatorJson = '{"href":"/chapter1.xhtml","type":"text/html"}';
    await deps.progressRepository.saveProgress(
      ReadingProgressEntity(
        bookId: 'book-2',
        locatorJson: locatorJson,
        percent: 0.35,
        updatedAt: DateTime.now(),
      ),
    );

    await store.openBook('book-2');

    expect(store.state.locatorJson, locatorJson);
    expect(store.state.bookPercent, 0.35);
  });

  test('updateLocator updates state with locator JSON', () async {
    final deps = await _createDeps();
    final store = await _seedBook(deps: deps, bookId: 'book-3');

    await store.openBook('book-3');
    store.updateLocator('{"href":"/chapter2.xhtml"}', percent: 0.5);

    expect(store.state.locatorJson, '{"href":"/chapter2.xhtml"}');
    expect(store.state.bookPercent, 0.5);
  });

  test('flushProgress saves locator to repository immediately', () async {
    final deps = await _createDeps();
    final store = await _seedBook(deps: deps, bookId: 'book-4');

    await store.openBook('book-4');
    store.updateLocator('{"href":"/chapter3.xhtml"}', percent: 0.7);
    await store.flushProgress();

    final saved = await deps.progressRepository.getProgress('book-4');
    expect(saved?.locatorJson, '{"href":"/chapter3.xhtml"}');
    expect(saved?.percent, 0.7);
  });

  test('flushProgress saves progress without extra state notifications', () async {
    final deps = await _createDeps();
    final store = await _seedBook(deps: deps, bookId: 'book-5');

    var notifyCount = 0;
    store.addListener(() {
      notifyCount++;
    });

    await store.openBook('book-5');
    store.updateLocator('{"href":"/chapter4.xhtml"}', percent: 0.8);
    notifyCount = 0;

    await store.flushProgress();

    final saved = await deps.progressRepository.getProgress('book-5');
    expect(saved?.locatorJson, '{"href":"/chapter4.xhtml"}');
    expect(notifyCount, 0);
  });

  test('updatePreferences persists preferences per book', () async {
    final deps = await _createDeps();
    final store = await _seedBook(deps: deps, bookId: 'book-6');

    await store.openBook('book-6');
    await store.updatePreferences((current) => current.copyWith(fontSize: 22));

    final reloaded = ReaderStore(
      bookRepository: deps.bookRepository,
      progressRepository: deps.progressRepository,
      readerPreferencesRepository: deps.readerPreferencesRepository,
    );
    await reloaded.openBook('book-6');

    expect(reloaded.state.preferences?.fontSize, 22);
  });

  test('savedLocatorJson returns current locator', () async {
    final deps = await _createDeps();
    final store = await _seedBook(deps: deps, bookId: 'book-7');

    await store.openBook('book-7');
    store.updateLocator('{"href":"/chapter5.xhtml"}');

    expect(store.savedLocatorJson, '{"href":"/chapter5.xhtml"}');
  });

  test('savedLocatorJson returns updated locator after updateLocator', () async {
    final deps = await _createDeps();
    final store = await _seedBook(deps: deps, bookId: 'book-8');

    await store.openBook('book-8');
    store.updateLocator('{"href":"/chapter6.xhtml","type":"text/html"}');

    expect(store.savedLocatorJson, '{"href":"/chapter6.xhtml","type":"text/html"}');
  });

  test('onReaderReady sets isReaderReady to true', () async {
    final deps = await _createDeps();
    final store = await _seedBook(deps: deps, bookId: 'book-9');

    await store.openBook('book-9');
    expect(store.state.isReaderReady, false);

    store.onReaderReady();
    expect(store.state.isReaderReady, true);
  });
}
