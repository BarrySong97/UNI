import '../../dtos/db/reader-pagination-cache-dto.dart';
import '../../entities/reader-pagination-cache-entity.dart';
import '../../services/db/daos/reader-pagination-cache-dao.dart';
import 'reader-pagination-cache-repository.dart';

class ReaderPaginationCacheRepositoryImpl
    implements ReaderPaginationCacheRepository {
  ReaderPaginationCacheRepositoryImpl({
    required ReaderPaginationCacheDao cacheDao,
  }) : _cacheDao = cacheDao;

  final ReaderPaginationCacheDao _cacheDao;

  @override
  Future<ReaderPaginationCacheEntity?> getCache({
    required String bookId,
    required String layoutKey,
    required String cacheKind,
    required int chapterStart,
    required int chapterEnd,
  }) async {
    final dto = await _cacheDao.getCache(
      bookId: bookId,
      layoutKey: layoutKey,
      cacheKind: cacheKind,
      chapterStart: chapterStart,
      chapterEnd: chapterEnd,
    );
    return dto?.toEntity();
  }

  @override
  Future<void> saveCache(ReaderPaginationCacheEntity cache) {
    return _cacheDao.upsertCache(ReaderPaginationCacheDto.fromEntity(cache));
  }

  @override
  Future<void> pruneBookCaches({
    required String bookId,
    required int keepCount,
  }) {
    return _cacheDao.pruneBookCaches(bookId: bookId, keepCount: keepCount);
  }
}
