import '../../dtos/db/reader-preferences-dto.dart';
import '../../entities/reader-preferences-entity.dart';
import '../../services/db/daos/reader-preferences-dao.dart';
import 'reader-preferences-repository.dart';

class ReaderPreferencesRepositoryImpl implements ReaderPreferencesRepository {
  ReaderPreferencesRepositoryImpl({
    required ReaderPreferencesDao preferencesDao,
  }) : _preferencesDao = preferencesDao;

  final ReaderPreferencesDao _preferencesDao;

  @override
  Future<ReaderPreferencesEntity?> getByBookId(String bookId) async {
    final dto = await _preferencesDao.getByBookId(bookId);
    return dto?.toEntity();
  }

  @override
  Future<void> savePreferences(ReaderPreferencesEntity preferences) {
    return _preferencesDao.upsertPreferences(
      ReaderPreferencesDto.fromEntity(preferences),
    );
  }
}
