enum StatisticsTab { readingTime, booksRead }

enum StatisticsPeriodPreset { thisMonth, thisYear, pickedMonth }

class StatisticsPageArguments {
  const StatisticsPageArguments({
    required this.initialTab,
    required this.initialPeriodPreset,
    this.pickedMonth,
  });

  final StatisticsTab initialTab;
  final StatisticsPeriodPreset initialPeriodPreset;
  final DateTime? pickedMonth;
}
