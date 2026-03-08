import 'package:flutter/material.dart';

abstract final class ShelfDesignTokens {
  // Reading stats cards
  static const double statsCardRadius = 14;
  static const Color statsCardBg = Color(0xFFFAF9F7);
  static const Color statsLabelColor = Color(0xFF8B7355);
  static const Color statsNumberColor = Color(0xFF5C4A3A);
  static const Color statsBarColor = Color(0xFFCCC5BC);
  static const Color statsBooksReadBg = Color(0xFF5C4A3A);
  static const Color statsBooksReadText = Color(0xFFFAF9F7);

  // Now Reading card
  static const double nowReadingCardRadius = 18;
  static const double nowReadingCoverWidth = 100;
  static const double nowReadingCoverHeight = 140;
  static const double nowReadingCoverRadius = 8;
  static const Color nowReadingCardBg = Color(0xFFFAF9F7);
  static const Color nowReadingCoverPlaceholderBg = Color(0xFFE8E4DF);
  static const Color nowReadingProgressBg = Color(0xFFEDE8E0);
  static const Color nowReadingProgressFill = Color(0xFF1A1A1A);
  static const Color continueButtonBg = Color(0xFF1A1A1A);
  static const Color continueButtonText = Color(0xFFFFFFFF);
  static const double continueButtonRadius = 24;

  // Word of the Day
  static const double wordOfDayCardRadius = 16;
  static const Color wordOfDayCardBg = Color(0xFFE8E4DF);
  static const Color wordOfDayIconBg = Color(0xFFD5CFC6);
  static const Color wordOfDayIconColor = Color(0xFF8B7355);

  // Home book list (horizontal scroll)
  static const double homeGridCoverRadius = 12;
  static const int homeGridMaxItems = 8;
  static const double homeGridItemWidth = 150;
  static const double homeGridItemSpacing = 14;
  static const double homeGridTitleSize = 14;
  static const double homeGridAuthorSize = 12;
  static const double homeGridProgressHeight = 3;
  static const Color homeGridProgressBg = Color(0xFFE0DCD7);
  static const Color homeGridProgressFill = Color(0xFF1A1A1A);

  // Section header
  static const double sectionHeaderSize = 18;
  static const Color sectionHeaderColor = Color(0xFF0E0E0E);
  static const Color viewAllColor = Color(0xFF8B7355);
  static const double viewAllSize = 13;
}
