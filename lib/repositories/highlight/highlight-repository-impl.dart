import '../../dtos/db/highlight-dto.dart';
import '../../entities/highlight-entity.dart';
import '../../services/db/daos/highlights-dao.dart';
import 'highlight-repository.dart';

class HighlightRepositoryImpl implements HighlightRepository {
  HighlightRepositoryImpl({required HighlightsDao highlightsDao})
    : _highlightsDao = highlightsDao;

  final HighlightsDao _highlightsDao;

  @override
  Future<List<HighlightEntity>> getHighlights(String bookId) async {
    final list = await _highlightsDao.listByBookId(bookId);
    return list.map((dto) => dto.toEntity()).toList(growable: false);
  }

  @override
  Future<HighlightEntity> createHighlight(HighlightEntity highlight) async {
    await _highlightsDao.upsertHighlight(HighlightDto.fromEntity(highlight));
    return highlight;
  }

  @override
  Future<void> deleteHighlight(String highlightId) {
    return _highlightsDao.deleteHighlight(highlightId);
  }
}
