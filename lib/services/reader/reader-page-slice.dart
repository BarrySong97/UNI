class ReaderPageSlice {
  const ReaderPageSlice({
    required this.chapterIndex,
    required this.chapterId,
    required this.chapterTitle,
    required this.startOffset,
    required this.endOffset,
    required this.globalStartOffset,
    required this.globalEndOffset,
    required this.text,
  });

  final int chapterIndex;
  final String chapterId;
  final String chapterTitle;
  final int startOffset;
  final int endOffset;
  final int globalStartOffset;
  final int globalEndOffset;
  final String text;
}
