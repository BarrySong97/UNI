import 'package:flutter_test/flutter_test.dart';
import 'package:uni/entities/reading-progress-entity.dart';
import 'package:uni/repositories/progress/progress-repository.dart';
import 'package:uni/services/library/book-profile-entry-service.dart';

class _FakeProgressRepository implements ProgressRepository {
  final Map<String, ReadingProgressEntity> _storage = <String, ReadingProgressEntity>{};

  @override
  Future<ReadingProgressEntity?> getProgress(String bookId) async {
    return _storage[bookId];
  }

  @override
  Future<void> saveProgress(ReadingProgressEntity progress) async {
    _storage[progress.bookId] = progress;
  }
}

void main() {
  test('returns profile when no reading progress exists', () async {
    final service = BookProfileEntryService(progressRepository: _FakeProgressRepository());

    final target = await service.resolveEntry('book-1');

    expect(target, BookProfileEntryTarget.profile);
  });

  test('returns reader when reading progress exists', () async {
    final repository = _FakeProgressRepository();
    await repository.saveProgress(
      ReadingProgressEntity(
        bookId: 'book-1',
        chapterId: 'chapter-1',
        charOffset: 10,
        percent: 0.4,
        updatedAt: DateTime.now(),
      ),
    );

    final service = BookProfileEntryService(progressRepository: repository);
    final target = await service.resolveEntry('book-1');

    expect(target, BookProfileEntryTarget.reader);
  });
}
