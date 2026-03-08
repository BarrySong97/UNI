import 'package:flutter/material.dart';

import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';

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
        color: ShelfDesignTokens.wordOfDayCardBg,
        borderRadius: BorderRadius.circular(ShelfDesignTokens.wordOfDayCardRadius),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ShelfDesignTokens.wordOfDayIconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome,
              size: 20,
              color: ShelfDesignTokens.wordOfDayIconColor,
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
                    color: CommonDesignTokens.textSecondary,
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
                    color: CommonDesignTokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 22,
            color: CommonDesignTokens.textSecondary,
          ),
        ],
      ),
      ),
    );
  }
}
