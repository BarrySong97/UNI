class ChapterPaginationService {
  int nextChapterIndex({required int currentIndex, required int total}) {
    if (total <= 0) {
      return 0;
    }
    return (currentIndex + 1).clamp(0, total - 1).toInt();
  }

  int previousChapterIndex({required int currentIndex}) {
    return (currentIndex - 1).clamp(0, currentIndex).toInt();
  }
}
