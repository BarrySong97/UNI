class ReadingProgressEntity {
  const ReadingProgressEntity({
    required this.bookId,
    required this.locatorJson,
    required this.percent,
    required this.updatedAt,
    this.prefsJson,
  });

  final String bookId;
  final String locatorJson;
  final double percent;
  final DateTime updatedAt;
  final String? prefsJson;

  ReadingProgressEntity copyWith({
    String? locatorJson,
    double? percent,
    DateTime? updatedAt,
    String? prefsJson,
    bool clearPrefsJson = false,
  }) {
    return ReadingProgressEntity(
      bookId: bookId,
      locatorJson: locatorJson ?? this.locatorJson,
      percent: percent ?? this.percent,
      updatedAt: updatedAt ?? this.updatedAt,
      prefsJson: clearPrefsJson ? null : (prefsJson ?? this.prefsJson),
    );
  }
}
