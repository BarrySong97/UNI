import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../dtos/db/book-dto.dart';
import '../../dtos/db/chapter-dto.dart';
import '../../dtos/db/highlight-dto.dart';
import '../../dtos/db/reading-progress-dto.dart';
import 'tables/books-table.dart';
import 'tables/chapters-table.dart';
import 'tables/explain-cache-table.dart';
import 'tables/highlights-table.dart';
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
      version: 14,
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
  ${BooksTable.epubFilePath} TEXT,
  ${BooksTable.language} TEXT,
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
  ${ReadingProgressTable.locatorJson} TEXT NOT NULL,
  ${ReadingProgressTable.percent} REAL NOT NULL,
  ${ReadingProgressTable.updatedAt} INTEGER NOT NULL,
  ${ReadingProgressTable.prefsJson} TEXT,
  ${ReadingProgressTable.pageCountsJson} TEXT
)
''');
        await db.execute('''
CREATE TABLE ${HighlightsTable.tableName} (
  ${HighlightsTable.id} TEXT PRIMARY KEY,
  ${HighlightsTable.bookId} TEXT NOT NULL,
  ${HighlightsTable.locatorJson} TEXT NOT NULL,
  ${HighlightsTable.selectedText} TEXT NOT NULL,
  ${HighlightsTable.color} TEXT NOT NULL,
  ${HighlightsTable.note} TEXT,
  ${HighlightsTable.createdAt} INTEGER NOT NULL,
  ${HighlightsTable.updatedAt} INTEGER NOT NULL
)
''');
        await db.execute(
          'CREATE INDEX idx_chapters_book_idx ON ${ChaptersTable.tableName} (${ChaptersTable.bookId}, ${ChaptersTable.idx})',
        );
        await db.execute(
          'CREATE INDEX idx_highlights_book ON ${HighlightsTable.tableName} (${HighlightsTable.bookId})',
        );
        await db.execute('''
CREATE TABLE ${ExplainCacheTable.tableName} (
  ${ExplainCacheTable.bookId} TEXT NOT NULL,
  ${ExplainCacheTable.chapterIndex} INTEGER NOT NULL,
  ${ExplainCacheTable.selectedText} TEXT NOT NULL,
  ${ExplainCacheTable.contextSentence} TEXT NOT NULL DEFAULT '',
  ${ExplainCacheTable.response} TEXT NOT NULL,
  ${ExplainCacheTable.createdAt} INTEGER NOT NULL,
  PRIMARY KEY (${ExplainCacheTable.bookId}, ${ExplainCacheTable.chapterIndex}, ${ExplainCacheTable.selectedText}, ${ExplainCacheTable.contextSentence})
)
''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 7) {
          await _migrateToV7(db);
        }
        if (oldVersion < 8) {
          // V8: Visual pagination cache table (now removed in V9)
        }
        if (oldVersion < 9) {
          await _migrateToV9(db);
        }
        if (oldVersion < 10) {
          await _migrateToV10(db);
        }
        if (oldVersion < 11) {
          await _migrateToV11(db);
        }
        if (oldVersion < 12) {
          await _migrateToV12(db);
        }
        if (oldVersion < 13) {
          await _migrateToV13(db);
        }
        if (oldVersion < 14) {
          await _migrateToV14(db);
        }
      },
    );
    return AppDatabase._(_SqfliteBackend(database));
  }

  static Future<void> _migrateToV7(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${BooksTable.tableName} ADD COLUMN ${BooksTable.epubFilePath} TEXT',
    );

    await db.execute('DROP TABLE IF EXISTS reading_progress');
    await db.execute('''
CREATE TABLE ${ReadingProgressTable.tableName} (
  ${ReadingProgressTable.bookId} TEXT PRIMARY KEY,
  ${ReadingProgressTable.locatorJson} TEXT NOT NULL,
  ${ReadingProgressTable.percent} REAL NOT NULL,
  ${ReadingProgressTable.updatedAt} INTEGER NOT NULL
)
''');

    await db.execute('DROP TABLE IF EXISTS highlights');
    await db.execute('''
CREATE TABLE ${HighlightsTable.tableName} (
  ${HighlightsTable.id} TEXT PRIMARY KEY,
  ${HighlightsTable.bookId} TEXT NOT NULL,
  ${HighlightsTable.locatorJson} TEXT NOT NULL,
  ${HighlightsTable.selectedText} TEXT NOT NULL,
  ${HighlightsTable.color} TEXT NOT NULL,
  ${HighlightsTable.note} TEXT,
  ${HighlightsTable.createdAt} INTEGER NOT NULL,
  ${HighlightsTable.updatedAt} INTEGER NOT NULL
)
''');
    await db.execute(
      'CREATE INDEX idx_highlights_book ON ${HighlightsTable.tableName} (${HighlightsTable.bookId})',
    );

    await db.execute('DROP TABLE IF EXISTS reader_pagination_slices');
    await db.execute('DROP TABLE IF EXISTS reader_pagination_cache');
    await db.execute('DROP TABLE IF EXISTS book_images');

    await db.execute('DELETE FROM ${ChaptersTable.tableName}');
  }

  static Future<void> _migrateToV10(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${ReadingProgressTable.tableName} ADD COLUMN ${ReadingProgressTable.prefsJson} TEXT',
    );
  }

  static Future<void> _migrateToV11(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${ReadingProgressTable.tableName} ADD COLUMN ${ReadingProgressTable.pageCountsJson} TEXT',
    );
  }

  static Future<void> _migrateToV12(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE ${BooksTable.tableName} ADD COLUMN ${BooksTable.language} TEXT',
    );
  }

  static Future<void> _migrateToV13(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS ${ExplainCacheTable.tableName} (
  ${ExplainCacheTable.bookId} TEXT NOT NULL,
  ${ExplainCacheTable.chapterIndex} INTEGER NOT NULL,
  ${ExplainCacheTable.selectedText} TEXT NOT NULL,
  ${ExplainCacheTable.response} TEXT NOT NULL,
  ${ExplainCacheTable.createdAt} INTEGER NOT NULL,
  PRIMARY KEY (${ExplainCacheTable.bookId}, ${ExplainCacheTable.chapterIndex}, ${ExplainCacheTable.selectedText})
)
''');
  }

  static Future<void> _migrateToV14(DatabaseExecutor db) async {
    // Recreate explain_cache with context_sentence column added to PK.
    await db.execute('DROP TABLE IF EXISTS ${ExplainCacheTable.tableName}');
    await db.execute('''
CREATE TABLE ${ExplainCacheTable.tableName} (
  ${ExplainCacheTable.bookId} TEXT NOT NULL,
  ${ExplainCacheTable.chapterIndex} INTEGER NOT NULL,
  ${ExplainCacheTable.selectedText} TEXT NOT NULL,
  ${ExplainCacheTable.contextSentence} TEXT NOT NULL DEFAULT '',
  ${ExplainCacheTable.response} TEXT NOT NULL,
  ${ExplainCacheTable.createdAt} INTEGER NOT NULL,
  PRIMARY KEY (${ExplainCacheTable.bookId}, ${ExplainCacheTable.chapterIndex}, ${ExplainCacheTable.selectedText}, ${ExplainCacheTable.contextSentence})
)
''');
  }

  static Future<void> _migrateToV9(DatabaseExecutor db) async {
    // Drop reader-specific tables while preserving user data
    await db.execute('DROP TABLE IF EXISTS reader_preferences');
    await db.execute('DROP TABLE IF EXISTS reader_visual_pagination_cache');
    // Note: reading_progress, highlights, books tables are preserved
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

  Future<List<ReadingProgressDto>> getAllProgress() =>
      _backend.getAllProgress();

  Future<void> upsertProgress(ReadingProgressDto progress) =>
      _backend.upsertProgress(progress);

  Future<List<HighlightDto>> listHighlights(
    String bookId, {
    String? chapterId,
  }) {
    return _backend.listHighlights(bookId);
  }

  Future<void> upsertHighlight(HighlightDto highlight) =>
      _backend.upsertHighlight(highlight);

  Future<void> deleteHighlight(String highlightId) =>
      _backend.deleteHighlight(highlightId);

  Future<String?> getExplainCache({
    required String bookId,
    required int chapterIndex,
    required String selectedText,
    required String contextSentence,
  }) => _backend.getExplainCache(
        bookId: bookId,
        chapterIndex: chapterIndex,
        selectedText: selectedText,
        contextSentence: contextSentence,
      );

  Future<void> upsertExplainCache({
    required String bookId,
    required int chapterIndex,
    required String selectedText,
    required String contextSentence,
    required String response,
  }) => _backend.upsertExplainCache(
        bookId: bookId,
        chapterIndex: chapterIndex,
        selectedText: selectedText,
        contextSentence: contextSentence,
        response: response,
      );
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
  Future<List<ReadingProgressDto>> getAllProgress();
  Future<void> upsertProgress(ReadingProgressDto progress);
  Future<List<HighlightDto>> listHighlights(String bookId);
  Future<void> upsertHighlight(HighlightDto highlight);
  Future<void> deleteHighlight(String highlightId);
  Future<String?> getExplainCache({
    required String bookId,
    required int chapterIndex,
    required String selectedText,
    required String contextSentence,
  });
  Future<void> upsertExplainCache({
    required String bookId,
    required int chapterIndex,
    required String selectedText,
    required String contextSentence,
    required String response,
  });
}

class _InMemoryBackend implements _DatabaseBackend {
  final Map<String, BookDto> _books = <String, BookDto>{};
  final Map<String, ChapterDto> _chapters = <String, ChapterDto>{};
  final Map<String, ReadingProgressDto> _progress =
      <String, ReadingProgressDto>{};
  final Map<String, HighlightDto> _highlights = <String, HighlightDto>{};
  // key: "bookId|chapterIndex|selectedText"
  final Map<String, String> _explainCache = <String, String>{};

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
    _explainCache.removeWhere((key, _) => key.startsWith('$bookId|'));
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
  Future<List<ReadingProgressDto>> getAllProgress() async =>
      _progress.values.toList(growable: false);

  @override
  Future<void> upsertProgress(ReadingProgressDto progress) async {
    _progress[progress.bookId] = progress;
  }

  @override
  Future<List<HighlightDto>> listHighlights(String bookId) async {
    final filtered = _highlights.values.where((item) => item.bookId == bookId);
    final list = filtered.toList(growable: false)
      ..sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
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
  Future<String?> getExplainCache({
    required String bookId,
    required int chapterIndex,
    required String selectedText,
    required String contextSentence,
  }) async {
    return _explainCache['$bookId|$chapterIndex|$selectedText|$contextSentence'];
  }

  @override
  Future<void> upsertExplainCache({
    required String bookId,
    required int chapterIndex,
    required String selectedText,
    required String contextSentence,
    required String response,
  }) async {
    _explainCache['$bookId|$chapterIndex|$selectedText|$contextSentence'] = response;
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
      BooksTable.epubFilePath: book.epubFilePath,
      BooksTable.language: book.language,
      BooksTable.createdAt: book.createdAtMillis,
      BooksTable.updatedAt: book.updatedAtMillis,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteBookCascade(String bookId) async {
    await _database.transaction((txn) async {
      await txn.delete(
        ExplainCacheTable.tableName,
        where: '${ExplainCacheTable.bookId} = ?',
        whereArgs: <Object?>[bookId],
      );
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
  Future<List<ReadingProgressDto>> getAllProgress() async {
    final rows = await _database.query(ReadingProgressTable.tableName);
    return rows.map(_progressFromRow).toList(growable: false);
  }

  @override
  Future<void> upsertProgress(ReadingProgressDto progress) {
    return _database.insert(ReadingProgressTable.tableName, <String, Object?>{
      ReadingProgressTable.bookId: progress.bookId,
      ReadingProgressTable.locatorJson: progress.locatorJson,
      ReadingProgressTable.percent: progress.percent,
      ReadingProgressTable.updatedAt: progress.updatedAtMillis,
      ReadingProgressTable.prefsJson: progress.prefsJson,
      ReadingProgressTable.pageCountsJson: progress.pageCountsJson,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<HighlightDto>> listHighlights(String bookId) async {
    final rows = await _database.query(
      HighlightsTable.tableName,
      where: '${HighlightsTable.bookId} = ?',
      whereArgs: <Object?>[bookId],
      orderBy: '${HighlightsTable.createdAt} ASC',
    );
    return rows.map(_highlightFromRow).toList(growable: false);
  }

  @override
  Future<void> upsertHighlight(HighlightDto highlight) {
    return _database.insert(HighlightsTable.tableName, <String, Object?>{
      HighlightsTable.id: highlight.id,
      HighlightsTable.bookId: highlight.bookId,
      HighlightsTable.locatorJson: highlight.locatorJson,
      HighlightsTable.selectedText: highlight.selectedText,
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
      epubFilePath: row[BooksTable.epubFilePath] as String?,
      language: row[BooksTable.language] as String?,
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
      locatorJson: row[ReadingProgressTable.locatorJson]! as String,
      percent: (row[ReadingProgressTable.percent]! as num).toDouble(),
      updatedAtMillis: row[ReadingProgressTable.updatedAt]! as int,
      prefsJson: row[ReadingProgressTable.prefsJson] as String?,
      pageCountsJson: row[ReadingProgressTable.pageCountsJson] as String?,
    );
  }

  HighlightDto _highlightFromRow(Map<String, Object?> row) {
    return HighlightDto(
      id: row[HighlightsTable.id]! as String,
      bookId: row[HighlightsTable.bookId]! as String,
      locatorJson: row[HighlightsTable.locatorJson]! as String,
      selectedText: row[HighlightsTable.selectedText]! as String,
      color: row[HighlightsTable.color]! as String,
      note: row[HighlightsTable.note] as String?,
      createdAtMillis: row[HighlightsTable.createdAt]! as int,
      updatedAtMillis: row[HighlightsTable.updatedAt]! as int,
    );
  }

  @override
  Future<String?> getExplainCache({
    required String bookId,
    required int chapterIndex,
    required String selectedText,
    required String contextSentence,
  }) async {
    final rows = await _database.query(
      ExplainCacheTable.tableName,
      columns: [ExplainCacheTable.response],
      where:
          '${ExplainCacheTable.bookId} = ? AND ${ExplainCacheTable.chapterIndex} = ? AND ${ExplainCacheTable.selectedText} = ? AND ${ExplainCacheTable.contextSentence} = ?',
      whereArgs: <Object?>[bookId, chapterIndex, selectedText, contextSentence],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first[ExplainCacheTable.response] as String?;
  }

  @override
  Future<void> upsertExplainCache({
    required String bookId,
    required int chapterIndex,
    required String selectedText,
    required String contextSentence,
    required String response,
  }) {
    return _database.insert(
      ExplainCacheTable.tableName,
      <String, Object?>{
        ExplainCacheTable.bookId: bookId,
        ExplainCacheTable.chapterIndex: chapterIndex,
        ExplainCacheTable.selectedText: selectedText,
        ExplainCacheTable.contextSentence: contextSentence,
        ExplainCacheTable.response: response,
        ExplainCacheTable.createdAt:
            DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
