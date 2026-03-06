import '../../entities/highlight-entity.dart';

abstract class HighlightRepository {
  Future<List<HighlightEntity>> getHighlights(String bookId);

  Future<HighlightEntity> createHighlight(HighlightEntity highlight);

  Future<void> deleteHighlight(String highlightId);
}
