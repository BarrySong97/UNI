import 'package:flutter/material.dart';

import '../../shared/constants/library-design-tokens.dart';

class WordOfDayCard extends StatelessWidget {
  const WordOfDayCard({this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: LibraryDesignTokens.wordOfDayCardBg,
        borderRadius: BorderRadius.circular(LibraryDesignTokens.wordOfDayCardRadius),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: LibraryDesignTokens.wordOfDayIconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome,
              size: 20,
              color: LibraryDesignTokens.wordOfDayIconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text(
                  'WORD OF THE DAY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: LibraryDesignTokens.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '"Serendipity"',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: LibraryDesignTokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 22,
            color: LibraryDesignTokens.textSecondary,
          ),
        ],
      ),
      ),
    );
  }
}
