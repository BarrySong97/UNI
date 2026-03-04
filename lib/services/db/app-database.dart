import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../dtos/db/book-dto.dart';
import '../../dtos/db/chapter-dto.dart';
import '../../dtos/db/highlight-dto.dart';
import '../../dtos/db/reader-pagination-cache-dto.dart';
import '../../dtos/db/reader-preferences-dto.dart';
import '../../dtos/db/reading-progress-dto.dart';
import 'tables/books-table.dart';
import 'tables/chapters-table.dart';
import 'tables/highlights-table.dart';
import 'tables/reader-pagination-cache-table.dart';
import 'tables/reader-preferences-table.dart';
import 'tables/reading-progress-table.dart';

class AppDatabase {
  AppDatabase() : _backend = _InMemoryBackend();

  AppDatabase._(this._backend);

  final _DatabaseBackend _backend;

  static Future<AppDatabase> openPersistent() async {
    final root = await getDatabasesPath();
    final path = p.join(root, 'uni_reader.db');
    final database = await openDatabase(
      path,
      version: 5,
      onCreate: (db, _) async {
        await db.execute('''
CREATE TABLE ${BooksTable.tableName} (
  ${BooksTable.id} TEXT PRIMARY KEY,
  ${BooksTable.title} TEXT NOT NULL,
  ${BooksTable.author} TEXT NOT NULL,
  ${BooksTable.coverUrl} TEXT,
  ${BooksTable.profileBgColor} TEXT,
  ${BooksTable.estimatedTotalPages} INTEGER,
  ${BooksTable.sourceType} TEXT NOT NULL,
  ${BooksTable.sourcePath} TEXT,
  ${BooksTable.createdAt} INTEGER NOT NULL,
  ${BooksTable.updatedAt} INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE ${ChaptersTable.tableName} (
  ${ChaptersTable.id} TEXT PRIMARY KEY,
  ${ChaptersTable.bookId} TEXT NOT NULL,
  ${ChaptersTable.idx} INTEGER NOT NULL,
  ${ChaptersTable.title} TEXT NOT NULL,
  ${ChaptersTable.content} TEXT NOT NULL,
  ${ChaptersTable.wordCount} INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE ${ReadingProgressTable.tableName} (
  ${ReadingProgressTable.bookId} TEXT PRIMARY KEY,
  ${ReadingProgressTable.chapterId} TEXT NOT NULL,
  ${ReadingProgressTable.charOffset} INTEGER NOT NULL,
  ${ReadingProgressTable.percent} REAL NOT NULL,
  ${ReadingProgressTable.updatedAt} INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE ${HighlightsTable.tableName} (
  ${HighlightsTable.id} TEXT PRIMARY KEY,
  ${HighlightsTable.bookId} TEXT NOT NULL,
  ${HighlightsTable.chapterId} TEXT NOT NULL,
  ${HighlightsTable.startOffset} INTEGER NOT NULL,
  ${HighlightsTable.endOffset} INTEGER NOT NULL,
  ${HighlightsTable.selectedText} TEXT NOT NULL,
  ${HighlightsTable.prefixContext} TEXT NOT NULL,
  ${HighlightsTable.suffixContext} TEXT NOT NULL,
  ${HighlightsTable.color} TEXT NOT NULL,
  ${HighlightsTable.note} TEXT,
  ${HighlightsTable.createdAt} INTEGER NOT NULL,
  ${HighlightsTable.updatedAt} INTEGER NOT NULL
)
''');
        await _createReaderPreferencesTable(db);
        await _createReaderPaginationCacheTables(db);
        await db.execute(
          'CREATE INDEX idx_chapters_book_idx ON ${ChaptersTable.tableName} (${ChaptersTable.bookId}, ${ChaptersTable.idx})',
        );
        await db.execute(
          'CREATE INDEX idx_highlights_book_chapter_start ON ${HighlightsTable.tableName} (${HighlightsTable.bookId}, ${HighlightsTable.chapterId}, ${HighlightsTable.startOffset})',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE ${BooksTable.tableName} ADD COLUMN ${BooksTable.profileBgColor} TEXT',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE ${BooksTable.tableName} ADD COLUMN ${BooksTable.estimatedTotalPages} INTEGER',
          );
        }
        if (oldVersion < 4) {
          await _createReaderPreferencesTable(db);
        }
        if (oldVersion < 5) {
          await _createReaderPaginationCacheTables(db);
        }
      },
    );
    return AppDatabase._(_SqfliteBackend(database));
  }

  Future<List<BookDto>> listBooks() => _backend.listBooks();

  Future<BookDto?> getBook(String bookId) => _backend.getBook(bookId);

  Future<void> upsertBook(BookDto book) => _backend.upsertBook(book);
  Future<void> deleteBookCascade(String bookId) =>
      _backend.deleteBookCascade(bookId);

  Future<void> upsertChapter(ChapterDto chapter) =>
      _backend.upsertChapter(chapter);

  Future<ChapterDto?> getChapter(String chapterId) =>
      _backend.getChapter(chapterId);

  Future<List<ChapterDto>> listChaptersByBook(String bookId) =>
      _backend.listChaptersByBook(bookId);

  Future<ReadingProgressDto?> getProgress(String bookId) =>
      _backend.getProgress(bookId);

  Future<void> upsertProgress(ReadingProgressDto progress) =>
      _backend.upsertProgress(progress);

  Future<List<HighlightDto>> listHighlights(
    String bookId, {
    String? chapterId,
  }) {
    return _backend.listHighlights(bookId, chapterId: chapterId);
  }

  Future<void> upsertHighlight(HighlightDto highlight) =>
      _backend.upsertHighlight(highlight);

  Future<void> deleteHighlight(String highlightId) =>
      _backend.deleteHighlight(highlightId);

  Future<ReaderPreferencesDto?> getReaderPreferences(String bookId) =>
      _backend.getReaderPreferences(bookId);

  Future<void> upsertReaderPreferences(ReaderPreferencesDto preferences) =>
      _backend.upsertReaderPreferences(preferences);

  Future<ReaderPaginationCacheDto?> getReaderPaginationCache({
    required String bookId,
    required String layoutKey,
    required String cacheKind,
    required int chapterStart,
    required int chapterEnd,
  }) => _backend.getReaderPaginationCache(
    bookId: bookId,
    layoutKey: layoutKey,
    cacheKind: cacheKind,
    chapterStart: chapterStart,
    chapterEnd: chapterEnd,
  );

  Future<void> upsertReaderPaginationCache(ReaderPaginationCacheDto cache) =>
      _backend.upsertReaderPaginationCache(cache);

  Future<void> pruneReaderPaginationCaches({
    required String bookId,
    required int keepCount,
  }) => _backend.pruneReaderPaginationCaches(
    bookId: bookId,
    keepCount: keepCount,
  );

  static Future<void> _createReaderPreferencesTable(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE ${ReaderPreferencesTable.tableName} (
  ${ReaderPreferencesTable.bookId} TEXT PRIMARY KEY,
  ${ReaderPreferencesTable.fontSize} REAL NOT NULL,
  ${ReaderPreferencesTable.pagePaddingLevel} INTEGER NOT NULL,
  ${ReaderPreferencesTable.lineHeightLevel} INTEGER NOT NULL,
  ${ReaderPreferencesTable.letterSpacing} REAL NOT NULL,
  ${ReaderPreferencesTable.textColor} INTEGER NOT NULL,
  ${ReaderPreferencesTable.backgroundColor} INTEGER NOT NULL,
  ${ReaderPreferencesTable.brightness} REAL NOT NULL,
  ${ReaderPreferencesTable.fontFamily} TEXT NOT NULL,
  ${ReaderPreferencesTable.firstLineIndent} INTEGER NOT NULL,
  ${ReaderPreferencesTable.pageTurnMode} TEXT NOT NULL
)
''');
  }

  static Future<void> _createReaderPaginationCacheTables(
    DatabaseExecutor db,
  ) async {
    await db.execute('''
CREATE TABLE ${ReaderPaginationCacheTable.tableName} (
  ${ReaderPaginationCacheTable.id} TEXT PRIMARY KEY,
  ${ReaderPaginationCacheTable.bookId} TEXT NOT NULL,
  ${ReaderPaginationCacheTable.layoutKey} TEXT NOT NULL,
  ${ReaderPaginationCacheTable.cacheKind} TEXT NOT NULL,
  ${ReaderPaginationCacheTable.chapterStart} INTEGER NOT NULL,
  ${ReaderPaginationCacheTable.chapterEnd} INTEGER NOT NULL,
  ${ReaderPaginationCacheTable.pageCount} INTEGER NOT NULL,
  ${ReaderPaginationCacheTable.updatedAt} INTEGER NOT NULL
)
''');
    await db.execute('''
CREATE TABLE ${ReaderPaginationSliceTable.tableName} (
  ${ReaderPaginationSliceTable.cacheId} TEXT NOT NULL,
  ${ReaderPaginationSliceTable.pageIndex} INTEGER NOT NULL,
  ${ReaderPaginationSliceTable.chapterIndex} INTEGER NOT NULL,
  ${ReaderPaginationSliceTable.startOffset} INTEGER NOT NULL,
  ${ReaderPaginationSliceTable.endOffset} INTEGER NOT NULL,
  PRIMARY KEY (${ReaderPaginationSliceTable.cacheId}, ${ReaderPaginationSliceTable.pageIndex})
)
''');
    await db.execute(
      'CREATE INDEX idx_reader_pagination_cache_book_updated ON ${ReaderPaginationCacheTable.tableName} (${ReaderPaginationCacheTable.bookId}, ${ReaderPaginationCacheTable.updatedAt} DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_reader_pagination_cache_book_layout ON ${ReaderPaginationCacheTable.tableName} (${ReaderPaginationCacheTable.bookId}, ${ReaderPaginationCacheTable.layoutKey}, ${ReaderPaginationCacheTable.cacheKind})',
    );
  }
}

abstract class _DatabaseBackend {
  Future<List<BookDto>> listBooks();
  Future<BookDto?> getBook(String bookId);
  Future<void> upsertBook(BookDto book);
  Future<void> deleteBookCascade(String bookId);
  Future<void> upsertChapter(ChapterDto chapter);
  Future<ChapterDto?> getChapter(String chapterId);
  Future<List<ChapterDto>> listChaptersByBook(String bookId);
  Future<ReadingProgressDto?> getProgress(String bookId);
  Future<void> upsertProgress(ReadingProgressDto progress);
  Future<List<HighlightDto>> listHighlights(String bookId, {String? chapterId});
  Future<void> upsertHighlight(HighlightDto highlight);
  Future<void> deleteHighlight(String highlightId);
  Future<ReaderPreferencesDto?> getReaderPreferences(String bookId);
  Future<void> upsertReaderPreferences(ReaderPreferencesDto preferences);
  Future<ReaderPaginationCacheDto?> getReaderPaginationCache({
    required String bookId,
    required String layoutKey,
    required String cacheKind,
    required int chapterStart,
    required int chapterEnd,
  });
  Future<void> upsertReaderPaginationCache(ReaderPaginationCacheDto cache);
  Future<void> pruneReaderPaginationCaches({
    required String bookId,
    required int keepCount,
  });
}

class _InMemoryBackend implements _DatabaseBackend {
  final Map<String, BookDto> _books = <String, BookDto>{};
  final Map<String, ChapterDto> _chapters = <String, ChapterDto>{};
  final Map<String, ReadingProgressDto> _progress =
      <String, ReadingProgressDto>{};
  final Map<String, HighlightDto> _highlights = <String, HighlightDto>{};
  final Map<String, ReaderPreferencesDto> _readerPreferences =
      <String, ReaderPreferencesDto>{};
  final Map<String, ReaderPaginationCacheDto> _readerPaginationCaches =
      <String, ReaderPaginationCacheDto>{};

  @override
  Future<List<BookDto>> listBooks() async =>
      _books.values.toList(growable: false);

  @override
  Future<BookDto?> getBook(String bookId) async => _books[bookId];

  @override
  Future<void> upsertBook(BookDto book) async {
    _books[book.id] = book;
  }

  @override
  Future<void> deleteBookCascade(String bookId) async {
    _books.remove(bookId);
    _chapters.removeWhere((_, chapter) => chapter.bookId == bookId);
    _progress.remove(bookId);
    _highlights.removeWhere((_, highlight) => highlight.bookId == bookId);
    _readerPreferences.remove(bookId);
    _readerPaginationCaches.removeWhere((_, cache) => cache.bookId == bookId);
  }

  @override
  Future<void> upsertChapter(ChapterDto chapter) async {
    _chapters[chapter.id] = chapter;
  }

  @override
  Future<ChapterDto?> getChapter(String chapterId) async =>
      _chapters[chapterId];

  @override
  Future<List<ChapterDto>> listChaptersByBook(String bookId) async {
    final list = _chapters.values
        .where((chapter) => chapter.bookId == bookId)
        .toList(growable: false);
    list.sort((a, b) => a.idx.compareTo(b.idx));
    return list;
  }

  @override
  Future<ReadingProgressDto?> getProgress(String bookId) async =>
      _progress[bookId];

  @override
  Future<void> upsertProgress(ReadingProgressDto progress) async {
    _progress[progress.bookId] = progress;
  }

  @override
  Future<List<HighlightDto>> listHighlights(
    String bookId, {
    String? chapterId,
  }) async {
    final filtered = _highlights.values.where(
      (item) =>
          item.bookId == bookId &&
          (chapterId == null || item.chapterId == chapterId),
    );
    final list = filtered.toList(growable: false)
      ..sort((a, b) {
        final start = a.startOffset.compareTo(b.startOffset);
        if (start != 0) {
          return start;
        }
        return a.updatedAtMillis.compareTo(b.updatedAtMillis);
      });
    return list;
  }

  @override
  Future<void> upsertHighlight(HighlightDto highlight) async {
    _highlights[highlight.id] = highlight;
  }

  @override
  Future<void> deleteHighlight(String highlightId) async {
    _highlights.remove(highlightId);
  }

  @override
  Future<ReaderPreferencesDto?> getReaderPreferences(String bookId) async =>
      _readerPreferences[bookId];

  @override
  Future<void> upsertReaderPreferences(ReaderPreferencesDto preferences) async {
    _readerPreferences[preferences.bookId] = preferences;
  }

  @override
  Future<ReaderPaginationCacheDto?> getReaderPaginationCache({
    required String bookId,
    required String layoutKey,
    required String cacheKind,
    required int chapterStart,
    required int chapterEnd,
  }) async {
    for (final cache in _readerPaginationCaches.values) {
      if (cache.bookId == bookId &&
          cache.layoutKey == layoutKey &&
          cache.cacheKind == cacheKind &&
          cache.chapterStart == chapterStart &&
          cache.chapterEnd == chapterEnd) {
        return cache;
      }
    }
    return null;
  }

  @override
  Future<void> upsertReaderPaginationCache(
    ReaderPaginationCacheDto cache,
  ) async {
    _readerPaginationCaches[cache.id] = cache;
  }

  @override
  Future<void> pruneReaderPaginationCaches({
    required String bookId,
    required int keepCount,
  }) async {
    final list =
        _readerPaginationCaches.values
            .where((cache) => cache.bookId == bookId)
            .toList(growable: false)
          ..sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
    if (list.length <= keepCount) {
      return;
    }
    for (final cache in list.skip(keepCount)) {
      _readerPaginationCaches.remove(cache.id);
    }
  }
}

class _SqfliteBackend implements _DatabaseBackend {
  _SqfliteBackend(this._database);

  final Database _database;

  @override
  Future<List<BookDto>> listBooks() async {
    final rows = await _database.query(
      BooksTable.tableName,
      orderBy: '${BooksTable.updatedAt} DESC',
    );
    return rows.map(_bookFromRow).toList(growable: false);
  }

  @override
  Future<BookDto?> getBook(String bookId) async {
    final rows = await _database.query(
      BooksTable.tableName,
      where: '${BooksTable.id} = ?',
      whereArgs: <Object?>[bookId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _bookFromRow(rows.first);
  }

  @override
  Future<void> upsertBook(BookDto book) {
    return _database.insert(BooksTable.tableName, <String, Object?>{
      BooksTable.id: book.id,
      BooksTable.title: book.title,
      BooksTable.author: book.author,
      BooksTable.coverUrl: book.coverUrl,
      BooksTable.profileBgColor: book.profileBgColor,
      BooksTable.estimatedTotalPages: book.estimatedTotalPages,
      BooksTable.sourceType: book.sourceType,
      BooksTable.sourcePath: book.sourcePath,
      BooksTable.createdAt: book.createdAtMillis,
      BooksTable.updatedAt: book.updatedAtMillis,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteBookCascade(String bookId) async {
    await _database.transaction((txn) async {
      await txn.delete(
        HighlightsTable.tableName,
        where: '${HighlightsTable.bookId} = ?',
        whereArgs: <Object?>[bookId],
      );
      await txn.delete(
        ReadingProgressTable.tableName,
        where: '${ReadingProgressTable.bookId} = ?',
        whereArgs: <Object?>[bookId],
      );
      await txn.delete(
        ReaderPreferencesTable.tableName,
        where: '${ReaderPreferencesTable.bookId} = ?',
        whereArgs: <Object?>[bookId],
      );
      final cacheRows = await txn.query(
        ReaderPaginationCacheTable.tableName,
        columns: <String>[ReaderPaginationCacheTable.id],
        where: '${ReaderPaginationCacheTable.bookId} = ?',
        whereArgs: <Object?>[bookId],
      );
      final cacheIds = cacheRows
          .map((row) => row[ReaderPaginationCacheTable.id]! as String)
          .toList(growable: false);
      for (final cacheId in cacheIds) {
        await txn.delete(
          ReaderPaginationSliceTable.tableName,
          where: '${ReaderPaginationSliceTable.cacheId} = ?',
          whereArgs: <Object?>[cacheId],
        );
      }
      await txn.delete(
        ReaderPaginationCacheTable.tableName,
        where: '${ReaderPaginationCacheTable.bookId} = ?',
        whereArgs: <Object?>[bookId],
      );
      await txn.delete(
        ChaptersTable.tableName,
        where: '${ChaptersTable.bookId} = ?',
        whereArgs: <Object?>[bookId],
      );
      await txn.delete(
        BooksTable.tableName,
        where: '${BooksTable.id} = ?',
        whereArgs: <Object?>[bookId],
      );
    });
  }

  @override
  Future<void> upsertChapter(ChapterDto chapter) {
    return _database.insert(ChaptersTable.tableName, <String, Object?>{
      ChaptersTable.id: chapter.id,
      ChaptersTable.bookId: chapter.bookId,
      ChaptersTable.idx: chapter.idx,
      ChaptersTable.title: chapter.title,
      ChaptersTable.content: chapter.content,
      ChaptersTable.wordCount: chapter.wordCount,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<ChapterDto?> getChapter(String chapterId) async {
    final rows = await _database.query(
      ChaptersTable.tableName,
      where: '${ChaptersTable.id} = ?',
      whereArgs: <Object?>[chapterId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _chapterFromRow(rows.first);
  }

  @override
  Future<List<ChapterDto>> listChaptersByBook(String bookId) async {
    final rows = await _database.query(
      ChaptersTable.tableName,
      where: '${ChaptersTable.bookId} = ?',
      whereArgs: <Object?>[bookId],
      orderBy: '${ChaptersTable.idx} ASC',
    );
    return rows.map(_chapterFromRow).toList(growable: false);
  }

  @override
  Future<ReadingProgressDto?> getProgress(String bookId) async {
    final rows = await _database.query(
      ReadingProgressTable.tableName,
      where: '${ReadingProgressTable.bookId} = ?',
      whereArgs: <Object?>[bookId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _progressFromRow(rows.first);
  }

  @override
  Future<void> upsertProgress(ReadingProgressDto progress) {
    return _database.insert(ReadingProgressTable.tableName, <String, Object?>{
      ReadingProgressTable.bookId: progress.bookId,
      ReadingProgressTable.chapterId: progress.chapterId,
      ReadingProgressTable.charOffset: progress.charOffset,
      ReadingProgressTable.percent: progress.percent,
      ReadingProgressTable.updatedAt: progress.updatedAtMillis,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<HighlightDto>> listHighlights(
    String bookId, {
    String? chapterId,
  }) async {
    final whereParts = <String>['${HighlightsTable.bookId} = ?'];
    final whereArgs = <Object?>[bookId];
    if (chapterId != null) {
      whereParts.add('${HighlightsTable.chapterId} = ?');
      whereArgs.add(chapterId);
    }
    final rows = await _database.query(
      HighlightsTable.tableName,
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy:
          '${HighlightsTable.startOffset} ASC, ${HighlightsTable.updatedAt} ASC',
    );
    return rows.map(_highlightFromRow).toList(growable: false);
  }

  @override
  Future<void> upsertHighlight(HighlightDto highlight) {
    return _database.insert(HighlightsTable.tableName, <String, Object?>{
      HighlightsTable.id: highlight.id,
      HighlightsTable.bookId: highlight.bookId,
      HighlightsTable.chapterId: highlight.chapterId,
      HighlightsTable.startOffset: highlight.startOffset,
      HighlightsTable.endOffset: highlight.endOffset,
      HighlightsTable.selectedText: highlight.selectedText,
      HighlightsTable.prefixContext: highlight.prefixContext,
      HighlightsTable.suffixContext: highlight.suffixContext,
      HighlightsTable.color: highlight.color,
      HighlightsTable.note: highlight.note,
      HighlightsTable.createdAt: highlight.createdAtMillis,
      HighlightsTable.updatedAt: highlight.updatedAtMillis,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteHighlight(String highlightId) {
    return _database.delete(
      HighlightsTable.tableName,
      where: '${HighlightsTable.id} = ?',
      whereArgs: <Object?>[highlightId],
    );
  }

  @override
  Future<ReaderPreferencesDto?> getReaderPreferences(String bookId) async {
    final rows = await _database.query(
      ReaderPreferencesTable.tableName,
      where: '${ReaderPreferencesTable.bookId} = ?',
      whereArgs: <Object?>[bookId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _readerPreferencesFromRow(rows.first);
  }

  @override
  Future<void> upsertReaderPreferences(ReaderPreferencesDto preferences) {
    return _database.insert(
      ReaderPreferencesTable.tableName,
      <String, Object?>{
        ReaderPreferencesTable.bookId: preferences.bookId,
        ReaderPreferencesTable.fontSize: preferences.fontSize,
        ReaderPreferencesTable.pagePaddingLevel: preferences.pagePaddingLevel,
        ReaderPreferencesTable.lineHeightLevel: preferences.lineHeightLevel,
        ReaderPreferencesTable.letterSpacing: preferences.letterSpacing,
        ReaderPreferencesTable.textColor: preferences.textColorValue,
        ReaderPreferencesTable.backgroundColor:
            preferences.backgroundColorValue,
        ReaderPreferencesTable.brightness: preferences.brightness,
        ReaderPreferencesTable.fontFamily: preferences.fontFamily,
        ReaderPreferencesTable.firstLineIndent: preferences.firstLineIndent,
        ReaderPreferencesTable.pageTurnMode: preferences.pageTurnMode,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<ReaderPaginationCacheDto?> getReaderPaginationCache({
    required String bookId,
    required String layoutKey,
    required String cacheKind,
    required int chapterStart,
    required int chapterEnd,
  }) async {
    final rows = await _database.query(
      ReaderPaginationCacheTable.tableName,
      where:
          '${ReaderPaginationCacheTable.bookId} = ? AND ${ReaderPaginationCacheTable.layoutKey} = ? AND ${ReaderPaginationCacheTable.cacheKind} = ? AND ${ReaderPaginationCacheTable.chapterStart} = ? AND ${ReaderPaginationCacheTable.chapterEnd} = ?',
      whereArgs: <Object?>[
        bookId,
        layoutKey,
        cacheKind,
        chapterStart,
        chapterEnd,
      ],
      orderBy: '${ReaderPaginationCacheTable.updatedAt} DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final cacheRow = rows.first;
    final cacheId = cacheRow[ReaderPaginationCacheTable.id]! as String;
    final sliceRows = await _database.query(
      ReaderPaginationSliceTable.tableName,
      where: '${ReaderPaginationSliceTable.cacheId} = ?',
      whereArgs: <Object?>[cacheId],
      orderBy: '${ReaderPaginationSliceTable.pageIndex} ASC',
    );
    final slices = sliceRows
        .map(_readerPaginationSliceFromRow)
        .toList(growable: false);
    return _readerPaginationCacheFromRow(cacheRow, slices: slices);
  }

  @override
  Future<void> upsertReaderPaginationCache(
    ReaderPaginationCacheDto cache,
  ) async {
    await _database.transaction((txn) async {
      await txn.insert(
        ReaderPaginationCacheTable.tableName,
        <String, Object?>{
          ReaderPaginationCacheTable.id: cache.id,
          ReaderPaginationCacheTable.bookId: cache.bookId,
          ReaderPaginationCacheTable.layoutKey: cache.layoutKey,
          ReaderPaginationCacheTable.cacheKind: cache.cacheKind,
          ReaderPaginationCacheTable.chapterStart: cache.chapterStart,
          ReaderPaginationCacheTable.chapterEnd: cache.chapterEnd,
          ReaderPaginationCacheTable.pageCount: cache.pageCount,
          ReaderPaginationCacheTable.updatedAt: cache.updatedAtMillis,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        ReaderPaginationSliceTable.tableName,
        where: '${ReaderPaginationSliceTable.cacheId} = ?',
        whereArgs: <Object?>[cache.id],
      );
      for (final slice in cache.slices) {
        await txn.insert(
          ReaderPaginationSliceTable.tableName,
          <String, Object?>{
            ReaderPaginationSliceTable.cacheId: cache.id,
            ReaderPaginationSliceTable.pageIndex: slice.pageIndex,
            ReaderPaginationSliceTable.chapterIndex: slice.chapterIndex,
            ReaderPaginationSliceTable.startOffset: slice.startOffset,
            ReaderPaginationSliceTable.endOffset: slice.endOffset,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> pruneReaderPaginationCaches({
    required String bookId,
    required int keepCount,
  }) async {
    final rows = await _database.query(
      ReaderPaginationCacheTable.tableName,
      columns: <String>[ReaderPaginationCacheTable.id],
      where: '${ReaderPaginationCacheTable.bookId} = ?',
      whereArgs: <Object?>[bookId],
      orderBy: '${ReaderPaginationCacheTable.updatedAt} DESC',
    );
    if (rows.length <= keepCount) {
      return;
    }
    final deleteRows = rows.skip(keepCount);
    await _database.transaction((txn) async {
      for (final row in deleteRows) {
        final cacheId = row[ReaderPaginationCacheTable.id]! as String;
        await txn.delete(
          ReaderPaginationSliceTable.tableName,
          where: '${ReaderPaginationSliceTable.cacheId} = ?',
          whereArgs: <Object?>[cacheId],
        );
        await txn.delete(
          ReaderPaginationCacheTable.tableName,
          where: '${ReaderPaginationCacheTable.id} = ?',
          whereArgs: <Object?>[cacheId],
        );
      }
    });
  }

  BookDto _bookFromRow(Map<String, Object?> row) {
    return BookDto(
      id: row[BooksTable.id]! as String,
      title: row[BooksTable.title]! as String,
      author: row[BooksTable.author]! as String,
      coverUrl: row[BooksTable.coverUrl] as String?,
      profileBgColor: row[BooksTable.profileBgColor] as String?,
      estimatedTotalPages: row[BooksTable.estimatedTotalPages] as int?,
      sourceType: row[BooksTable.sourceType]! as String,
      sourcePath: row[BooksTable.sourcePath] as String?,
      createdAtMillis: row[BooksTable.createdAt]! as int,
      updatedAtMillis: row[BooksTable.updatedAt]! as int,
    );
  }

  ChapterDto _chapterFromRow(Map<String, Object?> row) {
    return ChapterDto(
      id: row[ChaptersTable.id]! as String,
      bookId: row[ChaptersTable.bookId]! as String,
      idx: row[ChaptersTable.idx]! as int,
      title: row[ChaptersTable.title]! as String,
      content: row[ChaptersTable.content]! as String,
      wordCount: row[ChaptersTable.wordCount]! as int,
    );
  }

  ReadingProgressDto _progressFromRow(Map<String, Object?> row) {
    return ReadingProgressDto(
      bookId: row[ReadingProgressTable.bookId]! as String,
      chapterId: row[ReadingProgressTable.chapterId]! as String,
      charOffset: row[ReadingProgressTable.charOffset]! as int,
      percent: (row[ReadingProgressTable.percent]! as num).toDouble(),
      updatedAtMillis: row[ReadingProgressTable.updatedAt]! as int,
    );
  }

  HighlightDto _highlightFromRow(Map<String, Object?> row) {
    return HighlightDto(
      id: row[HighlightsTable.id]! as String,
      bookId: row[HighlightsTable.bookId]! as String,
      chapterId: row[HighlightsTable.chapterId]! as String,
      startOffset: row[HighlightsTable.startOffset]! as int,
      endOffset: row[HighlightsTable.endOffset]! as int,
      selectedText: row[HighlightsTable.selectedText]! as String,
      prefixContext: row[HighlightsTable.prefixContext]! as String,
      suffixContext: row[HighlightsTable.suffixContext]! as String,
      color: row[HighlightsTable.color]! as String,
      note: row[HighlightsTable.note] as String?,
      createdAtMillis: row[HighlightsTable.createdAt]! as int,
      updatedAtMillis: row[HighlightsTable.updatedAt]! as int,
    );
  }

  ReaderPreferencesDto _readerPreferencesFromRow(Map<String, Object?> row) {
    return ReaderPreferencesDto(
      bookId: row[ReaderPreferencesTable.bookId]! as String,
      fontSize: (row[ReaderPreferencesTable.fontSize]! as num).toDouble(),
      pagePaddingLevel: row[ReaderPreferencesTable.pagePaddingLevel]! as int,
      lineHeightLevel: row[ReaderPreferencesTable.lineHeightLevel]! as int,
      letterSpacing: (row[ReaderPreferencesTable.letterSpacing]! as num)
          .toDouble(),
      textColorValue: row[ReaderPreferencesTable.textColor]! as int,
      backgroundColorValue: row[ReaderPreferencesTable.backgroundColor]! as int,
      brightness: (row[ReaderPreferencesTable.brightness]! as num).toDouble(),
      fontFamily: row[ReaderPreferencesTable.fontFamily]! as String,
      firstLineIndent: row[ReaderPreferencesTable.firstLineIndent]! as int,
      pageTurnMode: row[ReaderPreferencesTable.pageTurnMode]! as String,
    );
  }

  ReaderPaginationSliceDto _readerPaginationSliceFromRow(
    Map<String, Object?> row,
  ) {
    return ReaderPaginationSliceDto(
      pageIndex: row[ReaderPaginationSliceTable.pageIndex]! as int,
      chapterIndex: row[ReaderPaginationSliceTable.chapterIndex]! as int,
      startOffset: row[ReaderPaginationSliceTable.startOffset]! as int,
      endOffset: row[ReaderPaginationSliceTable.endOffset]! as int,
    );
  }

  ReaderPaginationCacheDto _readerPaginationCacheFromRow(
    Map<String, Object?> row, {
    required List<ReaderPaginationSliceDto> slices,
  }) {
    return ReaderPaginationCacheDto(
      id: row[ReaderPaginationCacheTable.id]! as String,
      bookId: row[ReaderPaginationCacheTable.bookId]! as String,
      layoutKey: row[ReaderPaginationCacheTable.layoutKey]! as String,
      cacheKind: row[ReaderPaginationCacheTable.cacheKind]! as String,
      chapterStart: row[ReaderPaginationCacheTable.chapterStart]! as int,
      chapterEnd: row[ReaderPaginationCacheTable.chapterEnd]! as int,
      pageCount: row[ReaderPaginationCacheTable.pageCount]! as int,
      updatedAtMillis: row[ReaderPaginationCacheTable.updatedAt]! as int,
      slices: slices,
    );
  }
}
