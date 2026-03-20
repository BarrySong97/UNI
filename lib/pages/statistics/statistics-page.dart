import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/providers/app-providers.dart';
import '../../entities/statistics-entity.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/statistics-design-tokens.dart';
import '../../stores/statistics/statistics-store.dart';
import 'statistics-types.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({this.arguments, this.store, super.key});

  final StatisticsPageArguments? arguments;
  final StatisticsStore? store;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  StatisticsStore? _ownedStore;
  bool _initialized = false;

  StatisticsStore get _store => widget.store ?? _ownedStore!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (widget.store == null) {
      final providers = AppProvidersScope.of(context);
      final arguments = widget.arguments ?? _defaultArguments;
      _ownedStore = StatisticsStore(
        database: providers.database,
        initialTab: arguments.initialTab,
        initialPeriodPreset: arguments.initialPeriodPreset,
        initialPickedMonth: arguments.pickedMonth,
      );
    }
    unawaited(_store.initialize());
  }

  @override
  void dispose() {
    _ownedStore?.dispose();
    super.dispose();
  }

  static const StatisticsPageArguments _defaultArguments =
      StatisticsPageArguments(
        initialTab: StatisticsTab.readingTime,
        initialPeriodPreset: StatisticsPeriodPreset.thisMonth,
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: CommonDesignTokens.pageBackground,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: <Widget>[
                  _buildHeader(context),
                  const SizedBox(height: 22),
                  _buildControls(context),
                  const SizedBox(height: 22),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back,
            color: CommonDesignTokens.textPrimary,
          ),
          splashRadius: 20,
        ),
        const Expanded(
          child: Text(
            'Statistics',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CommonDesignTokens.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 4,
          child: GestureDetector(
            onTap: _openPeriodPicker,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: StatisticsDesignTokens.chipBg,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _periodLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: StatisticsDesignTokens.chipText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: Icon(Icons.keyboard_arrow_down, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 7,
          child: _StatisticsTabSwitch(
            selectedTab: _store.selectedTab,
            onChanged: _store.setTab,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_store.isLoading &&
        _store.readingTimeData == null &&
        _store.booksReadData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_store.errorMessage != null &&
        _store.readingTimeData == null &&
        _store.booksReadData == null) {
      return Center(
        child: Text(
          _store.errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CommonDesignTokens.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: _store.selectedTab == StatisticsTab.readingTime
          ? _buildReadingTimeView()
          : _buildBooksReadView(),
    );
  }

  Widget _buildReadingTimeView() {
    final data = _store.readingTimeData;
    if (data == null) {
      return const SizedBox.shrink();
    }
    final isYearView =
        _store.selectedPeriodPreset == StatisticsPeriodPreset.thisYear;
    final yearlyBarSeries = isYearView ? _buildYearlyBarSeries(data) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _StatisticsMetricCard(
                label: 'TOTAL TIME',
                backgroundColor: Colors.white,
                foregroundColor: CommonDesignTokens.textPrimary,
                value: _formatDuration(data.totalSeconds),
                showMutedBackgroundBars: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatisticsMetricCard(
                label: 'AVG / DAY',
                backgroundColor: StatisticsDesignTokens.heroBrown,
                foregroundColor: Colors.white,
                value: _formatAverageDuration(data.averageSecondsPerDay),
                trailingIcon: Icons.schedule,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _StatisticsSectionCard(
          title: isYearView ? yearlyBarSeries!.title : 'Daily Minutes',
          trailing: _rangeLabel(data.dailyStats),
          child: isYearView
              ? _BarChart(
                  items: yearlyBarSeries!.items,
                  highlightedIndex: _highlightedMonthIndex(),
                )
              : _DailyMinutesProgressChart(dailyStats: data.dailyStats),
        ),
        const SizedBox(height: 18),
        _StatisticsSectionCard(
          title: 'Reading Heatmap',
          trailingWidget: _HeatmapLegend(
            maxSeconds: _maxDailySeconds(data.dailyStats),
          ),
          child: _HeatmapChart(dailyStats: data.dailyStats),
        ),
      ],
    );
  }

  Widget _buildBooksReadView() {
    final data = _store.booksReadData;
    if (data == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _BooksReadHeroCard(
          title: _booksReadHeroTitle(),
          qualifiedCount: data.qualifiedCount,
        ),
        const SizedBox(height: 26),
        _SectionHeader(
          title: 'Qualified Books',
          trailingText: '${data.qualifiedCount} books',
        ),
        const SizedBox(height: 12),
        if (data.qualifiedBooks.isEmpty)
          _EmptyStatisticsCard(
            message: 'No books qualified in this time block yet.',
          )
        else
          Column(
            children: data.qualifiedBooks
                .map(
                  (book) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _QualifiedBookTile(book: book),
                  ),
                )
                .toList(growable: false),
          ),
        const SizedBox(height: 26),
        const _SectionHeader(
          title: 'Almost There',
          trailingIcon: Icons.arrow_outward,
        ),
        const SizedBox(height: 12),
        if (data.almostThereBooks.isEmpty)
          _EmptyStatisticsCard(
            message: 'No books are close to qualifying right now.',
          )
        else
          Column(
            children: data.almostThereBooks
                .map(
                  (book) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _AlmostThereTile(book: book),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  Future<void> _openPeriodPicker() async {
    final preset = await showModalBottomSheet<StatisticsPeriodPreset>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PeriodOptionTile(
                title: 'This Month',
                selected:
                    _store.selectedPeriodPreset ==
                    StatisticsPeriodPreset.thisMonth,
                onTap: () =>
                    Navigator.of(context).pop(StatisticsPeriodPreset.thisMonth),
              ),
              _PeriodOptionTile(
                title: 'This Year',
                selected:
                    _store.selectedPeriodPreset ==
                    StatisticsPeriodPreset.thisYear,
                onTap: () =>
                    Navigator.of(context).pop(StatisticsPeriodPreset.thisYear),
              ),
              _PeriodOptionTile(
                title: 'Pick Month',
                selected:
                    _store.selectedPeriodPreset ==
                    StatisticsPeriodPreset.pickedMonth,
                onTap: () => Navigator.of(
                  context,
                ).pop(StatisticsPeriodPreset.pickedMonth),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || preset == null) return;
    if (preset == StatisticsPeriodPreset.pickedMonth) {
      final pickedMonth = await _openMonthPicker();
      if (!mounted || pickedMonth == null) return;
      await _store.setPickedMonth(pickedMonth);
      return;
    }
    await _store.setPeriodPreset(preset);
  }

  Future<DateTime?> _openMonthPicker() {
    var visibleYear = (_store.pickedMonth ?? DateTime.now()).year;
    final selectedMonth = _store.pickedMonth ?? DateTime.now();

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Text(
                          'Pick Month',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            setModalState(() {
                              visibleYear -= 1;
                            });
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '$visibleYear',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setModalState(() {
                              visibleYear += 1;
                            });
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List<Widget>.generate(12, (index) {
                        final month = index + 1;
                        final candidate = DateTime(visibleYear, month, 1);
                        final isSelected =
                            selectedMonth.year == visibleYear &&
                            selectedMonth.month == month;
                        return GestureDetector(
                          onTap: () => Navigator.of(context).pop(candidate),
                          child: Container(
                            width: (MediaQuery.of(context).size.width - 72) / 3,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.black
                                  : StatisticsDesignTokens.chipBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _monthShortLabel(month),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _periodLabel() {
    switch (_store.selectedPeriodPreset) {
      case StatisticsPeriodPreset.thisMonth:
        return 'This Month';
      case StatisticsPeriodPreset.thisYear:
        return 'This Year';
      case StatisticsPeriodPreset.pickedMonth:
        final pickedMonth = _store.pickedMonth;
        if (pickedMonth == null) return 'Pick Month';
        return '${_monthShortLabel(pickedMonth.month)} ${pickedMonth.year}';
    }
  }

  String _booksReadHeroTitle() {
    switch (_store.selectedPeriodPreset) {
      case StatisticsPeriodPreset.thisMonth:
      case StatisticsPeriodPreset.pickedMonth:
        return 'MONTHLY GOAL ACHIEVEMENT';
      case StatisticsPeriodPreset.thisYear:
        return 'YEARLY GOAL ACHIEVEMENT';
    }
  }

  _BarSeries _buildYearlyBarSeries(ReadingTimeStatisticsData data) {
    final totalsByMonth = <int, int>{};
    for (final stat in data.dailyStats) {
      totalsByMonth[stat.date.month] =
          (totalsByMonth[stat.date.month] ?? 0) + stat.seconds;
    }
    return _BarSeries(
      title: 'Monthly Minutes',
      items: List<_BarItem>.generate(12, (index) {
        final month = index + 1;
        return _BarItem(
          label: _monthShortLabel(month),
          value: ((totalsByMonth[month] ?? 0) / 60).round(),
        );
      }),
    );
  }

  int _highlightedMonthIndex() {
    if (_store.selectedPeriodPreset != StatisticsPeriodPreset.thisYear) {
      return -1;
    }
    return DateTime.now().month - 1;
  }

  int _maxDailySeconds(List<DailyReadingStat> dailyStats) {
    var maxSeconds = 0;
    for (final stat in dailyStats) {
      if (stat.seconds > maxSeconds) {
        maxSeconds = stat.seconds;
      }
    }
    return maxSeconds;
  }

  String _rangeLabel(List<DailyReadingStat> dailyStats) {
    if (dailyStats.isEmpty) return '';
    final first = dailyStats.first.date;
    final last = dailyStats.last.date;
    if (_store.selectedPeriodPreset == StatisticsPeriodPreset.thisYear) {
      return '${_monthShortLabel(first.month)} - ${_monthShortLabel(last.month)}';
    }
    return '${_monthShortLabel(first.month)} ${first.day} - ${_monthShortLabel(last.month)} ${last.day}';
  }

  String _monthShortLabel(int month) {
    const labels = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return labels[month - 1];
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours == 0) {
      return '${minutes}m';
    }
    return '$hours h $minutes m';
  }

  String _formatAverageDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours == 0) {
      return '${math.max(minutes, 0)}m';
    }
    return '${hours}h ${minutes}m';
  }
}

class _StatisticsMetricCard extends StatelessWidget {
  const _StatisticsMetricCard({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.value,
    this.trailingIcon,
    this.showMutedBackgroundBars = false,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final String value;
  final IconData? trailingIcon;
  final bool showMutedBackgroundBars;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: StatisticsDesignTokens.softShadow,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          if (showMutedBackgroundBars)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List<Widget>.generate(18, (index) {
                  final height = 6.0 + (index % 5) * 5.0;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: height,
                      decoration: BoxDecoration(
                        color: foregroundColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: foregroundColor.withValues(alpha: 0.58),
                      ),
                    ),
                  ),
                  if (trailingIcon != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        trailingIcon,
                        size: 18,
                        color: foregroundColor.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatisticsSectionCard extends StatelessWidget {
  const _StatisticsSectionCard({
    required this.title,
    required this.child,
    this.trailing,
    this.trailingWidget,
  });

  final String title;
  final String? trailing;
  final Widget? trailingWidget;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final trailingContent =
        trailingWidget ??
        (trailing != null
            ? Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 13,
                  color: CommonDesignTokens.textSecondary,
                ),
              )
            : null);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: StatisticsDesignTokens.softShadow,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 300;
              final titleText = Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: StatisticsDesignTokens.strongText,
                ),
              );

              if (trailingContent == null) {
                return titleText;
              }

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    titleText,
                    const SizedBox(height: 8),
                    trailingContent,
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(child: titleText),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailingContent,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatisticsTabSwitch extends StatelessWidget {
  const _StatisticsTabSwitch({
    required this.selectedTab,
    required this.onChanged,
  });

  final StatisticsTab selectedTab;
  final ValueChanged<StatisticsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: StatisticsDesignTokens.chipBg,
        borderRadius: BorderRadius.circular(21),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: <Widget>[
              AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: selectedTab == StatisticsTab.readingTime
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Container(
                    key: const ValueKey<String>('statistics-tab-thumb'),
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  _StatisticsTabSwitchButton(
                    key: const ValueKey<String>('statistics-tab-reading-time'),
                    title: 'Reading Time',
                    isSelected: selectedTab == StatisticsTab.readingTime,
                    onTap: () => onChanged(StatisticsTab.readingTime),
                  ),
                  _StatisticsTabSwitchButton(
                    key: const ValueKey<String>('statistics-tab-books-read'),
                    title: 'Books Read',
                    isSelected: selectedTab == StatisticsTab.booksRead,
                    onTap: () => onChanged(StatisticsTab.booksRead),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatisticsTabSwitchButton extends StatelessWidget {
  const _StatisticsTabSwitchButton({
    required super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : StatisticsDesignTokens.chipInactiveText,
              ),
              child: Text(title),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyMinutesProgressChart extends StatelessWidget {
  const _DailyMinutesProgressChart({required this.dailyStats});

  static const double _chartHeight = 180;
  static const double _minimumVisibleFillHeight = 2;
  static const double _labelRowHeight = 20;
  static const double _labelSpacing = 12;
  static const int _secondsPerDay = 24 * 60 * 60;

  final List<DailyReadingStat> dailyStats;

  @override
  Widget build(BuildContext context) {
    final labelledDays = <int>{
      1,
      8,
      15,
      22,
      if (dailyStats.isNotEmpty) dailyStats.last.date.day,
    };

    return SizedBox(
      key: const ValueKey<String>('daily-minutes-chart'),
      height: _chartHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackHeight = math.max(
            0.0,
            constraints.maxHeight - _labelRowHeight - _labelSpacing,
          );

          return Column(
            children: <Widget>[
              SizedBox(
                height: trackHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List<Widget>.generate(dailyStats.length, (index) {
                    final stat = dailyStats[index];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: _DailyMinutesTrack(
                          stat: stat,
                          trackHeight: trackHeight,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: _labelSpacing),
              SizedBox(
                height: _labelRowHeight,
                child: Row(
                  children: List<Widget>.generate(dailyStats.length, (index) {
                    final stat = dailyStats[index];
                    return Expanded(
                      child: Center(
                        child: Text(
                          labelledDays.contains(stat.date.day)
                              ? '${stat.date.day}'
                              : '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: CommonDesignTokens.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static double fillHeightFor({
    required int seconds,
    required double trackHeight,
  }) {
    if (seconds <= 0) return 0;
    final proportionalHeight = trackHeight * (seconds / _secondsPerDay);
    return math.min(
      trackHeight,
      math.max(proportionalHeight, _minimumVisibleFillHeight),
    );
  }
}

class _DailyMinutesTrack extends StatelessWidget {
  const _DailyMinutesTrack({required this.stat, required this.trackHeight});

  final DailyReadingStat stat;
  final double trackHeight;

  @override
  Widget build(BuildContext context) {
    final fillHeight = _DailyMinutesProgressChart.fillHeightFor(
      seconds: stat.seconds,
      trackHeight: trackHeight,
    );
    final dateKey = _statisticsDateKey(stat.date);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        key: ValueKey<String>('daily-minutes-track-$dateKey'),
        color: StatisticsDesignTokens.heatmapEmpty,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (fillHeight > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  key: ValueKey<String>('daily-minutes-fill-$dateKey'),
                  height: fillHeight,
                  decoration: BoxDecoration(
                    color: StatisticsDesignTokens.heroBrown,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.items, this.highlightedIndex = -1});

  final List<_BarItem> items;
  final int highlightedIndex;

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<int>(
      0,
      (maxValue, item) => math.max(maxValue, item.value),
    );
    return SizedBox(
      height: 180,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List<Widget>.generate(items.length, (index) {
                final item = items[index];
                final isHighlighted = index == highlightedIndex;
                final heightFactor = maxValue <= 0
                    ? 0.04
                    : math.max(item.value / maxValue, 0.04);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heightFactor.toDouble().clamp(0.04, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: isHighlighted
                                ? StatisticsDesignTokens.heroBrown
                                : StatisticsDesignTokens.heatmapLevel1
                                      .withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List<Widget>.generate(items.length, (index) {
              final label = items[index].label;
              final shouldShow =
                  items.length <= 12 ||
                  index == 0 ||
                  index == items.length - 1 ||
                  index % math.max(1, items.length ~/ 5) == 0;
              return Expanded(
                child: Center(
                  child: Text(
                    shouldShow ? label : '',
                    style: const TextStyle(
                      fontSize: 11,
                      color: CommonDesignTokens.textSecondary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend({required this.maxSeconds});

  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'Less',
          style: TextStyle(
            fontSize: 12,
            color: CommonDesignTokens.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        for (final color in const <Color>[
          StatisticsDesignTokens.heatmapEmpty,
          StatisticsDesignTokens.heatmapLevel1,
          StatisticsDesignTokens.heatmapLevel2,
          StatisticsDesignTokens.heatmapLevel3,
          StatisticsDesignTokens.heatmapLevel4,
        ])
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        const SizedBox(width: 8),
        Text(
          maxSeconds > 0 ? 'More' : 'No data',
          style: const TextStyle(
            fontSize: 12,
            color: CommonDesignTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _HeatmapChart extends StatelessWidget {
  const _HeatmapChart({required this.dailyStats});

  final List<DailyReadingStat> dailyStats;

  @override
  Widget build(BuildContext context) {
    if (dailyStats.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxSeconds = dailyStats.fold<int>(
      0,
      (maxValue, stat) => math.max(maxValue, stat.seconds),
    );
    final firstDate = dailyStats.first.date;
    final startOffset = firstDate.weekday - DateTime.monday;
    final cells = List<DailyReadingStat?>.filled(
      startOffset,
      null,
      growable: true,
    )..addAll(dailyStats);
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final weekColumns = cells.length ~/ 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const <Widget>[
            Text(
              'M',
              style: TextStyle(
                fontSize: 12,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
            Text(
              'T',
              style: TextStyle(
                fontSize: 12,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
            Text(
              'W',
              style: TextStyle(
                fontSize: 12,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
            Text(
              'T',
              style: TextStyle(
                fontSize: 12,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
            Text(
              'F',
              style: TextStyle(
                fontSize: 12,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
            Text(
              'S',
              style: TextStyle(
                fontSize: 12,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
            Text(
              'S',
              style: TextStyle(
                fontSize: 12,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final totalGaps = math.max(weekColumns - 1, 0) * 4.0;
            final cellSize = ((constraints.maxWidth - totalGaps) / weekColumns)
                .clamp(4.0, 16.0)
                .toDouble();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List<Widget>.generate(weekColumns, (column) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: column == weekColumns - 1 ? 0 : 4,
                  ),
                  child: Column(
                    children: List<Widget>.generate(7, (row) {
                      final stat = cells[column * 7 + row];
                      return Container(
                        width: cellSize,
                        height: cellSize,
                        margin: EdgeInsets.only(bottom: row == 6 ? 0 : 4),
                        decoration: BoxDecoration(
                          color: _heatmapColor(stat?.seconds ?? 0, maxSeconds),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  Color _heatmapColor(int seconds, int maxSeconds) {
    if (seconds <= 0 || maxSeconds <= 0) {
      return StatisticsDesignTokens.heatmapEmpty;
    }
    final ratio = seconds / maxSeconds;
    if (ratio < 0.25) return StatisticsDesignTokens.heatmapLevel1;
    if (ratio < 0.5) return StatisticsDesignTokens.heatmapLevel2;
    if (ratio < 0.75) return StatisticsDesignTokens.heatmapLevel3;
    return StatisticsDesignTokens.heatmapLevel4;
  }
}

class _BooksReadHeroCard extends StatelessWidget {
  const _BooksReadHeroCard({required this.title, required this.qualifiedCount});

  final String title;
  final int qualifiedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
      decoration: BoxDecoration(
        color: StatisticsDesignTokens.heroBrown,
        borderRadius: BorderRadius.circular(34),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: StatisticsDesignTokens.softShadow,
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xE9FFFFFF),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              const Text(
                'Books Read:',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                '$qualifiedCount',
                style: const TextStyle(
                  fontSize: 52,
                  height: 0.95,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: StatisticsDesignTokens.heroBrownDark.withValues(
                alpha: 0.28,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.white,
                      ),
                      children: <InlineSpan>[
                        TextSpan(text: 'Criteria for qualified reading:\n'),
                        TextSpan(
                          text: 'progress >= 40% AND time >= 20 min',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailingText,
    this.trailingIcon,
  });

  final String title;
  final String? trailingText;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: StatisticsDesignTokens.strongText,
          ),
        ),
        const Spacer(),
        if (trailingText != null)
          Text(
            trailingText!,
            style: const TextStyle(
              fontSize: 13,
              color: CommonDesignTokens.textSecondary,
            ),
          ),
        if (trailingIcon != null)
          Icon(trailingIcon, size: 18, color: StatisticsDesignTokens.heroBrown),
      ],
    );
  }
}

class _QualifiedBookTile extends StatelessWidget {
  const _QualifiedBookTile({required this.book});

  final QualifiedBookStat book;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: StatisticsDesignTokens.softShadow,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: StatisticsDesignTokens.strongText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(book.progressPercent * 100).round()}% Progress   ${_formatMinutes(book.readingTimeSeconds)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: CommonDesignTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: StatisticsDesignTokens.successBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: StatisticsDesignTokens.successText,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlmostThereTile extends StatelessWidget {
  const _AlmostThereTile({required this.book});

  final AlmostThereBookStat book;

  @override
  Widget build(BuildContext context) {
    final progressText = '${(book.progressPercent * 100).round()}%';
    final hint = book.needsMoreProgress
        ? 'Needs ${book.remainingProgressPercent * 100 ~/ 1}% more progress'
        : 'Needs ${_formatMinutes(book.remainingTimeSeconds)} more time';
    final trailing = book.needsMoreTime ? 'TIME NEEDED' : 'PROGRESS NEEDED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: StatisticsDesignTokens.chipBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: StatisticsDesignTokens.strongText,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        progressText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: StatisticsDesignTokens.heroBrown,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CommonDesignTokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _formatMinutes(book.readingTimeSeconds),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: book.needsMoreTime
                      ? StatisticsDesignTokens.heroBrown
                      : StatisticsDesignTokens.successText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyStatisticsCard extends StatelessWidget {
  const _EmptyStatisticsCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: CommonDesignTokens.textSecondary,
        ),
      ),
    );
  }
}

class _PeriodOptionTile extends StatelessWidget {
  const _PeriodOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? Colors.black : CommonDesignTokens.textSecondary,
        ),
      ),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}

class _BarSeries {
  const _BarSeries({required this.title, required this.items});

  final String title;
  final List<_BarItem> items;
}

class _BarItem {
  const _BarItem({required this.label, required this.value});

  final String label;
  final int value;
}

String _formatMinutes(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours == 0) {
    return '${minutes}m';
  }
  return '${hours}h ${minutes}m';
}

String _statisticsDateKey(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
