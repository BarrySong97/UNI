enum BookProfileEntryTarget { profile, reader }

class BookProfileEntryService {
  const BookProfileEntryService();

  /// Resolves the entry target based on whether the book has reading progress.
  /// Uses the already-loaded [progressMap] from LibraryStore to avoid a
  /// redundant DB query.
  BookProfileEntryTarget resolveEntry(
    String bookId,
    Map<String, double> progressMap,
  ) {
    final percent = progressMap[bookId];
    if (percent == null || percent <= 0) {
      return BookProfileEntryTarget.profile;
    }
    return BookProfileEntryTarget.reader;
  }
}
