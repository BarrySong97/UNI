import '../../entities/book-entity.dart';
import '../../entities/chapter-entity.dart';

class ReaderState {
  const ReaderState({
    this.book,
    this.chapter,
    this.chapters = const <ChapterEntity>[],
    this.charOffset = 0,
    this.percent = 0,
    this.isLoading = false,
    this.isSaving = false,
  });

  final BookEntity? book;
  final ChapterEntity? chapter;
  final List<ChapterEntity> chapters;
  final int charOffset;
  final double percent;
  final bool isLoading;
  final bool isSaving;

  ReaderState copyWith({
    BookEntity? book,
    ChapterEntity? chapter,
    List<ChapterEntity>? chapters,
    int? charOffset,
    double? percent,
    bool? isLoading,
    bool? isSaving,
  }) {
    return ReaderState(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      chapters: chapters ?? this.chapters,
      charOffset: charOffset ?? this.charOffset,
      percent: percent ?? this.percent,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
