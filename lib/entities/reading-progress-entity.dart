class ReadingProgressEntity {
  const ReadingProgressEntity({
    required this.bookId,
    required this.locatorJson,
    required this.percent,
    required this.updatedAt,
    this.prefsJson,
    this.pageCountsJson,
  });

  final String bookId;
  final String locatorJson;
  final double percent;
  final DateTime updatedAt;
  final String? prefsJson;
  final String? pageCountsJson;

  ReadingProgressEntity copyWith({
    String? locatorJson,
    double? percent,
    DateTime? updatedAt,
    String? prefsJson,
    bool clearPrefsJson = false,
    String? pageCountsJson,
    bool clearPageCountsJson = false,
  }) {
    return ReadingProgressEntity(
      bookId: bookId,
      locatorJson: locatorJson ?? this.locatorJson,
      percent: percent ?? this.percent,
      updatedAt: updatedAt ?? this.updatedAt,
      prefsJson: clearPrefsJson ? null : (prefsJson ?? this.prefsJson),
      pageCountsJson: clearPageCountsJson
          ? null
          : (pageCountsJson ?? this.pageCountsJson),
    );
  }
}
