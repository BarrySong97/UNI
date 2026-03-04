import '../../../dtos/db/reader-pagination-cache-dto.dart';
import '../app-database.dart';

class ReaderPaginationCacheDao {
  ReaderPaginationCacheDao({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<ReaderPaginationCacheDto?> getCache({
    required String bookId,
    required String layoutKey,
    required String cacheKind,
    required int chapterStart,
    required int chapterEnd,
  }) {
    return _database.getReaderPaginationCache(
      bookId: bookId,
      layoutKey: layoutKey,
      cacheKind: cacheKind,
      chapterStart: chapterStart,
      chapterEnd: chapterEnd,
    );
  }

  Future<void> upsertCache(ReaderPaginationCacheDto dto) {
    return _database.upsertReaderPaginationCache(dto);
  }

  Future<void> pruneBookCaches({
    required String bookId,
    required int keepCount,
  }) {
    return _database.pruneReaderPaginationCaches(
      bookId: bookId,
      keepCount: keepCount,
    );
  }
}
