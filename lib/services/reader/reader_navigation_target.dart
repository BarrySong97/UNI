class ReaderNavigationTarget {
  const ReaderNavigationTarget({
    required this.source,
    required this.annotationId,
    required this.noteId,
    required this.chapterIndex,
    required this.blockIndex,
    required this.quoteText,
    required this.noteText,
  });

  final String source;
  final String annotationId;
  final String noteId;
  final int chapterIndex;
  final int blockIndex;
  final String quoteText;
  final String noteText;
}
