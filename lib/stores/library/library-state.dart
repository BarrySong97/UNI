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
  });

  final List<BookEntity> books;
  final List<BookEntity> filteredBooks;
  final List<String> categories;
  final String activeCategory;
  final bool isLoading;
  final bool isImporting;
  final String? lastImportMessage;
  final String? errorMessage;

  factory LibraryState.initial() => const LibraryState(
    books: <BookEntity>[],
    filteredBooks: <BookEntity>[],
    categories: <String>['ALL', 'FICTION', 'NON-FICTION', 'DESIGN', 'HISTORY'],
    activeCategory: 'ALL',
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
    );
  }
}
