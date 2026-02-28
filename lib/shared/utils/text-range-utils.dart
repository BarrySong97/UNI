class TextRangeUtils {
  static ({int start, int end}) normalize({
    required int start,
    required int end,
    required int max,
  }) {
    final normalizedStart = start.clamp(0, max).toInt();
    final normalizedEnd = end.clamp(normalizedStart, max).toInt();
    return (start: normalizedStart, end: normalizedEnd);
  }
}
