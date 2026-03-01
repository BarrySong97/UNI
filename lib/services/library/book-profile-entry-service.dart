import '../../repositories/progress/progress-repository.dart';

enum BookProfileEntryTarget { profile, reader }

class BookProfileEntryService {
  BookProfileEntryService({required ProgressRepository progressRepository})
    : _progressRepository = progressRepository;

  final ProgressRepository _progressRepository;

  Future<BookProfileEntryTarget> resolveEntry(String bookId) async {
    final progress = await _progressRepository.getProgress(bookId);
    if (progress == null) {
      return BookProfileEntryTarget.profile;
    }
    return BookProfileEntryTarget.reader;
  }
}
