import '../../entities/book-entity.dart';
import '../../entities/reader-preferences-entity.dart';

class ReaderState {
  const ReaderState({
    this.book,
    this.locatorJson,
    this.bookPercent = 0,
    this.preferences,
    this.isLoading = false,
    this.isSaving = false,
    this.isReaderReady = false,
  });

  final BookEntity? book;
  final String? locatorJson;
  final double bookPercent;
  final ReaderPreferencesEntity? preferences;
  final bool isLoading;
  final bool isSaving;
  final bool isReaderReady;

  ReaderState copyWith({
    BookEntity? book,
    String? locatorJson,
    double? bookPercent,
    ReaderPreferencesEntity? preferences,
    bool? isLoading,
    bool? isSaving,
    bool? isReaderReady,
  }) {
    return ReaderState(
      book: book ?? this.book,
      locatorJson: locatorJson ?? this.locatorJson,
      bookPercent: bookPercent ?? this.bookPercent,
      preferences: preferences ?? this.preferences,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isReaderReady: isReaderReady ?? this.isReaderReady,
    );
  }
}
