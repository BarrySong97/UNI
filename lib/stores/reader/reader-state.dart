import '../../entities/book-entity.dart';
import '../../entities/chapter-entity.dart';
import '../../entities/reader-preferences-entity.dart';
import '../../services/reader/reader-page-slice.dart';

class ReaderState {
  const ReaderState({
    this.book,
    this.chapter,
    this.chapters = const <ChapterEntity>[],
    this.currentChapterIndex = 0,
    this.charOffset = 0,
    this.bookPercent = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.currentPageIndex = 0,
    this.pageSlices = const <ReaderPageSlice>[],
    this.windowChapterStart = 0,
    this.windowChapterEnd = 0,
    this.isWindowReady = false,
    this.paginationSource = 'live',
    this.preferences,
    this.isLoading = false,
    this.isSaving = false,
    this.catalogMetricsStatus = 'idle',
    this.catalogChapterStartPages = const <int, int>{},
    this.catalogTotalPages = 1,
  });

  final BookEntity? book;
  final ChapterEntity? chapter;
  final List<ChapterEntity> chapters;
  final int currentChapterIndex;
  final int charOffset;
  final double bookPercent;
  final int currentPage;
  final int totalPages;
  final int currentPageIndex;
  final List<ReaderPageSlice> pageSlices;
  final int windowChapterStart;
  final int windowChapterEnd;
  final bool isWindowReady;
  final String paginationSource;
  final ReaderPreferencesEntity? preferences;
  final bool isLoading;
  final bool isSaving;
  final String catalogMetricsStatus;
  final Map<int, int> catalogChapterStartPages;
  final int catalogTotalPages;

  ReaderState copyWith({
    BookEntity? book,
    ChapterEntity? chapter,
    List<ChapterEntity>? chapters,
    int? currentChapterIndex,
    int? charOffset,
    double? bookPercent,
    int? currentPage,
    int? totalPages,
    int? currentPageIndex,
    List<ReaderPageSlice>? pageSlices,
    int? windowChapterStart,
    int? windowChapterEnd,
    bool? isWindowReady,
    String? paginationSource,
    ReaderPreferencesEntity? preferences,
    bool? isLoading,
    bool? isSaving,
    String? catalogMetricsStatus,
    Map<int, int>? catalogChapterStartPages,
    int? catalogTotalPages,
  }) {
    return ReaderState(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      chapters: chapters ?? this.chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      charOffset: charOffset ?? this.charOffset,
      bookPercent: bookPercent ?? this.bookPercent,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      pageSlices: pageSlices ?? this.pageSlices,
      windowChapterStart: windowChapterStart ?? this.windowChapterStart,
      windowChapterEnd: windowChapterEnd ?? this.windowChapterEnd,
      isWindowReady: isWindowReady ?? this.isWindowReady,
      paginationSource: paginationSource ?? this.paginationSource,
      preferences: preferences ?? this.preferences,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      catalogMetricsStatus: catalogMetricsStatus ?? this.catalogMetricsStatus,
      catalogChapterStartPages:
          catalogChapterStartPages ?? this.catalogChapterStartPages,
      catalogTotalPages: catalogTotalPages ?? this.catalogTotalPages,
    );
  }
}
