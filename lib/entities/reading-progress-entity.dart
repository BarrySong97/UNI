class ReadingProgressEntity {
  const ReadingProgressEntity({
    required this.bookId,
    required this.chapterId,
    required this.charOffset,
    required this.percent,
    required this.updatedAt,
  });

  final String bookId;
  final String chapterId;
  final int charOffset;
  final double percent;
  final DateTime updatedAt;

  ReadingProgressEntity copyWith({
    String? chapterId,
    int? charOffset,
    double? percent,
    DateTime? updatedAt,
  }) {
    return ReadingProgressEntity(
      bookId: bookId,
      chapterId: chapterId ?? this.chapterId,
      charOffset: charOffset ?? this.charOffset,
      percent: percent ?? this.percent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
