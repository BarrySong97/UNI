import 'package:flutter/material.dart';

import '../../entities/reading-time-entity.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';

class LibraryReadingStats extends StatelessWidget {
  const LibraryReadingStats({
    required this.readingTime,
    required this.booksReadThisYear,
    this.onReadingTimeTap,
    this.onBooksReadTap,
    super.key,
  });

  static const double _barChartHeight = 36;
  static const int _secondsPerDay = 24 * 60 * 60;

  final ReadingTimeEntity readingTime;
  final int booksReadThisYear;
  final VoidCallback? onReadingTimeTap;
  final VoidCallback? onBooksReadTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: GestureDetector(
            key: const ValueKey<String>('reading-time-stat-card'),
            behavior: HitTestBehavior.opaque,
            onTap: onReadingTimeTap,
            child: _buildDailyGoalCard(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            key: const ValueKey<String>('books-read-stat-card'),
            behavior: HitTestBehavior.opaque,
            onTap: onBooksReadTap,
            child: _buildBooksReadCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyGoalCard() {
    final hours = readingTime.totalSeconds ~/ 3600;
    final minutes = (readingTime.totalSeconds % 3600) ~/ 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                _monthLabel(readingTime.month),
                style: const TextStyle(
                  fontSize: 12,
                  color: ShelfDesignTokens.statsLabelColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          _buildTimeDisplay(hours, minutes),
          const SizedBox(height: 14),
          SizedBox(
            height: _barChartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (var i = 0; i < readingTime.dailySeconds.length; i++)
                  _buildDailyBar(i, readingTime.dailySeconds[i]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBar(int index, int seconds) {
    final ratio = (seconds / _secondsPerDay).clamp(0.0, 1.0);
    final backgroundColor = ShelfDesignTokens.statsBarColor.withValues(
      alpha: 0.32,
    );
    final fillColor = ShelfDesignTokens.statsNumberColor;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: DecoratedBox(
            key: ValueKey<String>('reading-bar-bg-$index'),
            decoration: BoxDecoration(color: backgroundColor),
            child: SizedBox(
              height: _barChartHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ratio == 0
                    ? const SizedBox.shrink()
                    : FractionallySizedBox(
                        heightFactor: ratio,
                        widthFactor: 1,
                        alignment: Alignment.bottomCenter,
                        child: DecoratedBox(
                          key: ValueKey<String>('reading-bar-fill-$index'),
                          decoration: BoxDecoration(color: fillColor),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBooksReadCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShelfDesignTokens.statsBooksReadBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                'BOOKS READ',
                style: TextStyle(
                  fontSize: 12,
                  color: ShelfDesignTokens.statsBooksReadText,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.menu_book_rounded,
                size: 18,
                color: ShelfDesignTokens.statsBooksReadText.withValues(
                  alpha: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '$booksReadThisYear',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: ShelfDesignTokens.statsBooksReadText,
                    height: 1.1,
                  ),
                ),
                TextSpan(
                  text: '  this year',
                  style: TextStyle(
                    fontSize: 14,
                    color: ShelfDesignTokens.statsBooksReadText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Book icon decoration at bottom right
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(
              Icons.auto_stories_outlined,
              size: 36,
              color: ShelfDesignTokens.statsBooksReadText.withValues(
                alpha: 0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _monthLabel(int month) {
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return months[month - 1];
  }

  Widget _buildTimeDisplay(int hours, int minutes) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: ShelfDesignTokens.statsNumberColor,
          height: 1.2,
        ),
        children: <InlineSpan>[
          TextSpan(
            text: '$hours',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: 'h '),
          TextSpan(
            text: '$minutes',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: 'm'),
        ],
      ),
    );
  }
}
