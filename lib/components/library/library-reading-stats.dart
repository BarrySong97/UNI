import 'package:flutter/material.dart';

import '../../shared/constants/shelf-design-tokens.dart';

class LibraryReadingStats extends StatelessWidget {
  const LibraryReadingStats({this.onTap, super.key});

  final VoidCallback? onTap;

  // Mock data - will be replaced with real data later
  static const int _mockMonthlyMinutes = 109;
  static const int _mockBooksRead = 12;

  static const List<double> _mockBarHeights = [
    0.3, 0.5, 0.8, 0.4, 0.6, 0.9, 0.7, 0.5, 0.3, 0.6,
    0.8, 0.4, 0.5, 0.7, 0.9, 0.6, 0.4, 0.8, 0.5, 0.3,
    0.7, 0.6, 0.4, 0.8, 0.5, 0.9, 0.3, 0.6, 0.7, 0.4,
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Expanded(child: _buildDailyGoalCard()),
          const SizedBox(width: 12),
          Expanded(child: _buildBooksReadCard()),
        ],
      ),
    );
  }

  Widget _buildDailyGoalCard() {
    final hours = _mockMonthlyMinutes ~/ 60;
    final minutes = _mockMonthlyMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShelfDesignTokens.statsCardBg,
        borderRadius: BorderRadius.circular(ShelfDesignTokens.statsCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                _currentMonthLabel(),
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
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _mockBarHeights.map((h) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    height: 36 * h,
                    decoration: BoxDecoration(
                      color: ShelfDesignTokens.statsBarColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksReadCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShelfDesignTokens.statsBooksReadBg,
        borderRadius: BorderRadius.circular(ShelfDesignTokens.statsCardRadius),
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
              Icon(Icons.menu_book_rounded, size: 18, color: ShelfDesignTokens.statsBooksReadText.withValues(alpha: 0.6)),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: const TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '$_mockBooksRead',
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
              color: ShelfDesignTokens.statsBooksReadText.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  static String _currentMonthLabel() {
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
    ];
    return months[DateTime.now().month - 1];
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
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(text: 'h '),
          TextSpan(
            text: '$minutes',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(text: 'm'),
        ],
      ),
    );
  }
}
