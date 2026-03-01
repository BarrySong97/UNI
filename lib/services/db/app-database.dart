import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../dtos/db/book-dto.dart';
import '../../dtos/db/chapter-dto.dart';
import '../../dtos/db/highlight-dto.dart';
import '../../dtos/db/reading-progress-dto.dart';
import 'tables/books-table.dart';
import 'tables/chapters-table.dart';
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
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
CREATE TABLE ${BooksTable.tableName} (
  ${BooksTable.id} TEXT PRIMARY KEY,
  ${BooksTable.title} TEXT NOT NULL,
  ${BooksTable.author} TEXT NOT NULL,
  ${BooksTable.coverUrl} TEXT,
  ${BooksTable.profileBgColor} TEXT,
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
}

class _InMemoryBackend implements _DatabaseBackend {
  final Map<String, BookDto> _books = <String, BookDto>{};
  final Map<String, ChapterDto> _chapters = <String, ChapterDto>{};
  final Map<String, ReadingProgressDto> _progress =
      <String, ReadingProgressDto>{};
  final Map<String, HighlightDto> _highlights = <String, HighlightDto>{};

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

  BookDto _bookFromRow(Map<String, Object?> row) {
    return BookDto(
      id: row[BooksTable.id]! as String,
      title: row[BooksTable.title]! as String,
      author: row[BooksTable.author]! as String,
      coverUrl: row[BooksTable.coverUrl] as String?,
      profileBgColor: row[BooksTable.profileBgColor] as String?,
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
}
