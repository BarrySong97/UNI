import '../../../dtos/db/highlight-dto.dart';
import '../app-database.dart';

class HighlightsDao {
  HighlightsDao({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<List<HighlightDto>> listByBookId(String bookId) {
    return _database.listHighlights(bookId);
  }

  Future<void> upsertHighlight(HighlightDto dto) =>
      _database.upsertHighlight(dto);

  Future<void> deleteHighlight(String highlightId) =>
      _database.deleteHighlight(highlightId);
}
