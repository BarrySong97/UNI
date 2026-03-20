import '../../entities/book-entity.dart';
import '../../entities/reading-time-entity.dart';

class LibraryState {
  LibraryState({
    required this.books,
    required this.filteredBooks,
    required this.categories,
    required this.activeCategory,
    required this.isLoading,
    this.isImporting = false,
    this.lastImportMessage,
    this.errorMessage,
    this.progressMap = const <String, double>{},
    this.progressLocatorMap = const <String, String>{},
    this.progressUpdatedMap = const <String, DateTime>{},
    required this.readingTime,
    this.booksReadThisYear = 0,
    this.lastImportedBookId,
  });

  final List<BookEntity> books;
  final List<BookEntity> filteredBooks;
  final List<String> categories;
  final String activeCategory;
  final bool isLoading;
  final bool isImporting;
  final String? lastImportMessage;
  final String? errorMessage;
  final Map<String, double> progressMap;
  final Map<String, String> progressLocatorMap;
  final Map<String, DateTime> progressUpdatedMap;
  final ReadingTimeEntity readingTime;
  final int booksReadThisYear;
  final String? lastImportedBookId;

  factory LibraryState.initial() {
    final now = DateTime.now();
    return LibraryState(
      books: const <BookEntity>[],
      filteredBooks: const <BookEntity>[],
      categories: const <String>['All', 'Reading', 'Finished'],
      activeCategory: 'All',
      isLoading: false,
      readingTime: ReadingTimeEntity.empty(year: now.year, month: now.month),
      booksReadThisYear: 0,
    );
  }

  LibraryState copyWith({
    List<BookEntity>? books,
    List<BookEntity>? filteredBooks,
    List<String>? categories,
    String? activeCategory,
    bool? isLoading,
    bool? isImporting,
    String? lastImportMessage,
    String? errorMessage,
    Map<String, double>? progressMap,
    Map<String, String>? progressLocatorMap,
    Map<String, DateTime>? progressUpdatedMap,
    ReadingTimeEntity? readingTime,
    int? booksReadThisYear,
    String? lastImportedBookId,
  }) {
    return LibraryState(
      books: books ?? this.books,
      filteredBooks: filteredBooks ?? this.filteredBooks,
      categories: categories ?? this.categories,
      activeCategory: activeCategory ?? this.activeCategory,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      lastImportMessage: lastImportMessage,
      errorMessage: errorMessage,
      progressMap: progressMap ?? this.progressMap,
      progressLocatorMap: progressLocatorMap ?? this.progressLocatorMap,
      progressUpdatedMap: progressUpdatedMap ?? this.progressUpdatedMap,
      readingTime: readingTime ?? this.readingTime,
      booksReadThisYear: booksReadThisYear ?? this.booksReadThisYear,
      lastImportedBookId: lastImportedBookId,
    );
  }
}
