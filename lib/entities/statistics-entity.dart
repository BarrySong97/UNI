class StatisticsTimeBlock {
  const StatisticsTimeBlock({
    required this.startInclusive,
    required this.endExclusive,
  });

  final DateTime startInclusive;
  final DateTime endExclusive;

  int get dayCount => endExclusive.difference(startInclusive).inDays;
}

class DailyReadingStat {
  const DailyReadingStat({required this.date, required this.seconds});

  final DateTime date;
  final int seconds;
}

class ReadingTimeStatisticsData {
  const ReadingTimeStatisticsData({
    required this.totalSeconds,
    required this.averageSecondsPerDay,
    required this.dailyStats,
  });

  final int totalSeconds;
  final int averageSecondsPerDay;
  final List<DailyReadingStat> dailyStats;
}

class QualifiedBookStat {
  const QualifiedBookStat({
    required this.bookId,
    required this.title,
    required this.progressPercent,
    required this.readingTimeSeconds,
  });

  final String bookId;
  final String title;
  final double progressPercent;
  final int readingTimeSeconds;
}

class AlmostThereBookStat extends QualifiedBookStat {
  const AlmostThereBookStat({
    required super.bookId,
    required super.title,
    required super.progressPercent,
    required super.readingTimeSeconds,
    required this.needsMoreProgress,
    required this.needsMoreTime,
    required this.remainingProgressPercent,
    required this.remainingTimeSeconds,
  });

  final bool needsMoreProgress;
  final bool needsMoreTime;
  final double remainingProgressPercent;
  final int remainingTimeSeconds;
}

class BooksReadStatisticsData {
  const BooksReadStatisticsData({
    required this.qualifiedCount,
    required this.qualifiedBooks,
    required this.almostThereBooks,
  });

  final int qualifiedCount;
  final List<QualifiedBookStat> qualifiedBooks;
  final List<AlmostThereBookStat> almostThereBooks;
}
