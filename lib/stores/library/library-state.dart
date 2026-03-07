import '../../entities/book-entity.dart';

class LibraryState {
  const LibraryState({
    required this.books,
    required this.filteredBooks,
    required this.categories,
    required this.activeCategory,
    required this.isLoading,
    this.isImporting = false,
    this.lastImportMessage,
    this.errorMessage,
    this.progressMap = const <String, double>{},
    this.progressUpdatedMap = const <String, DateTime>{},
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
  final Map<String, DateTime> progressUpdatedMap;
  final String? lastImportedBookId;

  factory LibraryState.initial() => const LibraryState(
    books: <BookEntity>[],
    filteredBooks: <BookEntity>[],
    categories: <String>['All', 'Reading', 'Finished'],
    activeCategory: 'All',
    isLoading: false,
  );

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
    Map<String, DateTime>? progressUpdatedMap,
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
      progressUpdatedMap: progressUpdatedMap ?? this.progressUpdatedMap,
      lastImportedBookId: lastImportedBookId,
    );
  }
}
