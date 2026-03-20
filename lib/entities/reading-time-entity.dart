class ReadingTimeEntity {
  ReadingTimeEntity({
    required this.year,
    required this.month,
    required this.totalSeconds,
    required this.dailySeconds,
  }) : assert(
         dailySeconds.length == _daysInMonth(year, month),
         'dailySeconds length must match the number of days in the month.',
       );

  final int year;
  final int month;
  final int totalSeconds;
  final List<int> dailySeconds;

  static ReadingTimeEntity empty({required int year, required int month}) {
    return ReadingTimeEntity(
      year: year,
      month: month,
      totalSeconds: 0,
      dailySeconds: List<int>.filled(_daysInMonth(year, month), 0),
    );
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
