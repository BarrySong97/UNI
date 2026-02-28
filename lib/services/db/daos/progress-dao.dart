import '../../../dtos/db/reading-progress-dto.dart';
import '../app-database.dart';

class ProgressDao {
  ProgressDao({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<ReadingProgressDto?> getByBookId(String bookId) => _database.getProgress(bookId);

  Future<void> upsertProgress(ReadingProgressDto dto) => _database.upsertProgress(dto);
}
