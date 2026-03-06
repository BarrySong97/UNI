class ReadingProgressEntity {
  const ReadingProgressEntity({
    required this.bookId,
    required this.locatorJson,
    required this.percent,
    required this.updatedAt,
  });

  final String bookId;
  final String locatorJson;
  final double percent;
  final DateTime updatedAt;

  ReadingProgressEntity copyWith({
    String? locatorJson,
    double? percent,
    DateTime? updatedAt,
  }) {
    return ReadingProgressEntity(
      bookId: bookId,
      locatorJson: locatorJson ?? this.locatorJson,
      percent: percent ?? this.percent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
