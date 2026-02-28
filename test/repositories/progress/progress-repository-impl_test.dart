import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/repositories/progress/progress-repository-impl.dart';
import 'package:uni/services/db/app-database.dart';
import 'package:uni/services/db/daos/progress-dao.dart';

void main() {
  test('save and read progress maps dto/entity correctly', () async {
    final repository = ProgressRepositoryImpl(progressDao: ProgressDao(database: AppDatabase()));

    final now = DateTime.now();
    final entity = ReadingProgressEntity(
      bookId: 'b1',
      chapterId: 'c1',
      charOffset: 12,
      percent: 0.66,
      updatedAt: now,
    );

    await repository.saveProgress(entity);
    final saved = await repository.getProgress('b1');

    expect(saved, isNotNull);
    expect(saved?.chapterId, 'c1');
    expect(saved?.charOffset, 12);
    expect(saved?.percent, 0.66);
  });
}
