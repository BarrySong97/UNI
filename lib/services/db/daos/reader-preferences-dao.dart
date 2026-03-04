import '../../../dtos/db/reader-preferences-dto.dart';
import '../app-database.dart';

class ReaderPreferencesDao {
  ReaderPreferencesDao({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<ReaderPreferencesDto?> getByBookId(String bookId) {
    return _database.getReaderPreferences(bookId);
  }

  Future<void> upsertPreferences(ReaderPreferencesDto dto) {
    return _database.upsertReaderPreferences(dto);
  }
}
