import 'package:flutter/foundation.dart';

import '../../entities/statistics-entity.dart';
import '../../pages/statistics/statistics-types.dart';
import '../../services/db/app-database.dart';

class StatisticsStore extends ChangeNotifier {
  StatisticsStore({
    required AppDatabase database,
    required StatisticsTab initialTab,
    required StatisticsPeriodPreset initialPeriodPreset,
    DateTime? initialPickedMonth,
    DateTime Function()? now,
    double progressThreshold = 0.4,
    int readingTimeThresholdSeconds = 20 * 60,
  }) : _database = database,
       _selectedTab = initialTab,
       _selectedPeriodPreset = initialPeriodPreset,
       _pickedMonth = _normalizeMonth(initialPickedMonth),
       _now = now ?? DateTime.now,
       _progressThreshold = progressThreshold,
       _readingTimeThresholdSeconds = readingTimeThresholdSeconds;

  final AppDatabase _database;
  final DateTime Function() _now;
  final double _progressThreshold;
  final int _readingTimeThresholdSeconds;

  StatisticsTab _selectedTab;
  StatisticsPeriodPreset _selectedPeriodPreset;
  DateTime? _pickedMonth;
  bool _isLoading = false;
  String? _errorMessage;
  ReadingTimeStatisticsData? _readingTimeData;
  BooksReadStatisticsData? _booksReadData;

  StatisticsTab get selectedTab => _selectedTab;
  StatisticsPeriodPreset get selectedPeriodPreset => _selectedPeriodPreset;
  DateTime? get pickedMonth => _pickedMonth;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ReadingTimeStatisticsData? get readingTimeData => _readingTimeData;
  BooksReadStatisticsData? get booksReadData => _booksReadData;

  StatisticsTimeBlock get timeBlock =>
      resolveTimeBlock(_selectedPeriodPreset, _pickedMonth, _now());

  static StatisticsTimeBlock resolveTimeBlock(
    StatisticsPeriodPreset preset,
    DateTime? pickedMonth,
    DateTime now,
  ) {
    switch (preset) {
      case StatisticsPeriodPreset.thisMonth:
        return StatisticsTimeBlock(
          startInclusive: DateTime(now.year, now.month, 1),
          endExclusive: DateTime(now.year, now.month + 1, 1),
        );
      case StatisticsPeriodPreset.thisYear:
        return StatisticsTimeBlock(
          startInclusive: DateTime(now.year, 1, 1),
          endExclusive: DateTime(now.year + 1, 1, 1),
        );
      case StatisticsPeriodPreset.pickedMonth:
        final month =
            _normalizeMonth(pickedMonth) ?? DateTime(now.year, now.month, 1);
        return StatisticsTimeBlock(
          startInclusive: month,
          endExclusive: DateTime(month.year, month.month + 1, 1),
        );
    }
  }

  Future<void> initialize() => reload();

  void setTab(StatisticsTab tab) {
    if (_selectedTab == tab) return;
    _selectedTab = tab;
    notifyListeners();
  }

  Future<void> setPeriodPreset(StatisticsPeriodPreset preset) async {
    if (_selectedPeriodPreset == preset) return;
    _selectedPeriodPreset = preset;
    if (preset != StatisticsPeriodPreset.pickedMonth) {
      notifyListeners();
      await reload();
      return;
    }
    notifyListeners();
  }

  Future<void> setPickedMonth(DateTime month) async {
    _pickedMonth = _normalizeMonth(month);
    _selectedPeriodPreset = StatisticsPeriodPreset.pickedMonth;
    notifyListeners();
    await reload();
  }

  Future<void> reload() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final block = timeBlock;

    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _database.getReadingTimeStatisticsInRange(
          startInclusive: block.startInclusive,
          endExclusive: block.endExclusive,
        ),
        _database.getBooksReadStatisticsInRange(
          startInclusive: block.startInclusive,
          endExclusive: block.endExclusive,
          progressThreshold: _progressThreshold,
          readingTimeThresholdSeconds: _readingTimeThresholdSeconds,
        ),
      ]);
      _readingTimeData = results[0] as ReadingTimeStatisticsData;
      _booksReadData = results[1] as BooksReadStatisticsData;
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  static DateTime? _normalizeMonth(DateTime? value) {
    if (value == null) return null;
    return DateTime(value.year, value.month, 1);
  }
}
