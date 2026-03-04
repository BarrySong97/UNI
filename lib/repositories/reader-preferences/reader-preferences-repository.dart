import '../../entities/reader-preferences-entity.dart';

abstract class ReaderPreferencesRepository {
  Future<ReaderPreferencesEntity?> getByBookId(String bookId);

  Future<void> savePreferences(ReaderPreferencesEntity preferences);
}
