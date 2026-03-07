import 'package:flutter/material.dart';

abstract final class LibraryDesignTokens {
  static const Color pageBackground = Color(0xFFF2F2F2);
  static const Color textPrimary = Color(0xFF0E0E0E);
  static const Color textSecondary = Color(0xFF737373);
  static const Color borderColor = Color(0xFFD9D9D9);
  static const Color tabActiveBg = Color(0xFF000000);
  static const Color tabInactiveBg = Color(0xFFF2F2F2);
  static const Color tabActiveText = Color(0xFFFFFFFF);
  static const Color tabInactiveText = Color(0xFF9E9E9E);

  static const Color coverBlue = Color(0xFF1549C7);
  static const Color coverNeon = Color(0xFFD7FF00);
  static const Color coverBlack = Color(0xFF13151A);
  static const Color coverGray = Color(0xFFCECCD0);
  static const Color coverTextLight = Color(0xFFF4F4F4);
  static const Color coverTextDark = Color(0xFF111111);

  static const double pageHorizontal = 10;
  static const double pageTopPadding = 8;
  static const double topBarHeight = 48;
  static const double topBarBottomGap = 24;
  static const double sectionTitleTopGap = 8;
  static const double sectionTitleBottomGap = 14;
  static const double categorySectionBottomGap = 16;
  static const double sectionDividerThickness = 1;
  static const double sectionDividerBottomGap = 16;

  static const double libraryTitleSize = 34;
  static const double recentTitleSize = 34;
  static const double headerBrandSize = 28;

  static const double tabHeight = 30;
  static const double tabHorizontalPadding = 10;
  static const double tabGap = 8;
  static const double tabBorderRadius = 10;

  static const double gridSpacing = 10;
  static const double gridRowSpacing = 16;
  static const double coverAspectRatio = 0.65;
  static const double bookTitleSize = 18;
  static const double bookAuthorSize = 12;

  static const double bottomBarHeight = 60;
  static const double bottomIconSize = 22;
  static const double bottomLabelSize = 12;

  static const double bookProfileTopTitleSize = 18;
  static const double bookProfileSectionLabelSize = 13;
  static const double bookProfileBookTitleSize = 19;
  static const double bookProfileMetaSize = 14;
  static const double bookProfileActionSize = 16;
  static const double bookProfileCollectionTitleSize = 18;
  static const double bookProfileCollectionAuthorSize = 14;

  static const Color bookProfileTopBgBase = Color(0xFFF2EEE8);
  static const Color bookProfileCollectionBg = Color(0xFFF7F7F7);
  static const Color bookProfileMutedText = Color(0xFF6E6E6E);
  static const double bookProfileTopGradientOpacityStart = 0.42;
  static const double bookProfileTopGradientOpacityEnd = 0.10;

  // Home header
  static const double headerLabelSize = 12;
  static const double headerTitleSize = 28;
  static const double avatarSize = 38;
  static const double avatarRadius = 10;
  static const Color avatarBg = Color(0xFF2C2C2C);
  static const Color avatarTextColor = Color(0xFFFFFFFF);
  static const Color headerLabelColor = Color(0xFF8B7355);

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
