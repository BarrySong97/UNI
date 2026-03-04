import '../../entities/reader-pagination-cache-entity.dart';

abstract class ReaderPaginationCacheRepository {
  Future<ReaderPaginationCacheEntity?> getCache({
    required String bookId,
    required String layoutKey,
    required String cacheKind,
    required int chapterStart,
    required int chapterEnd,
  });

  Future<void> saveCache(ReaderPaginationCacheEntity cache);

  Future<void> pruneBookCaches({
    required String bookId,
    required int keepCount,
  });
}
