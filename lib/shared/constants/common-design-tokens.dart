import 'package:flutter/material.dart';

abstract final class CommonDesignTokens {
  // Page
  static const Color pageBackground = Color(0xFFF2F2F2);
  static const double pageHorizontal = 10;
  static const double pageTopPadding = 8;

  // Typography
  static const Color textPrimary = Color(0xFF0E0E0E);
  static const Color textSecondary = Color(0xFF737373);
  static const Color borderColor = Color(0xFFD9D9D9);

  // Header
  static const double headerLabelSize = 12;
  static const double headerTitleSize = 28;
  static const double headerBrandSize = 28;
  static const Color headerLabelColor = Color(0xFF8B7355);

  // Avatar
  static const double avatarSize = 38;
  static const double avatarRadius = 10;
  static const Color avatarBg = Color(0xFF2C2C2C);
  static const Color avatarTextColor = Color(0xFFFFFFFF);

  // Common card
  static const double cardRadius = 18;
  static const Color cardBg = Color(0xFFFAF9F7);

  // Common typography sizes
  static const double bookTitleSize = 18;
  static const double bookAuthorSize = 12;
  static const double libraryTitleSize = 34;
  static const double recentTitleSize = 34;

  // Section layout
  static const double sectionTitleTopGap = 8;
  static const double sectionTitleBottomGap = 14;
  static const double categorySectionBottomGap = 16;
  static const double sectionDividerThickness = 1;
  static const double sectionDividerBottomGap = 16;
  static const double topBarHeight = 48;
  static const double topBarBottomGap = 24;

  // Cover colors
  static const Color coverBlue = Color(0xFF1549C7);
  static const Color coverNeon = Color(0xFFD7FF00);
  static const Color coverBlack = Color(0xFF13151A);
  static const Color coverGray = Color(0xFFCECCD0);
  static const Color coverTextLight = Color(0xFFF4F4F4);
  static const Color coverTextDark = Color(0xFF111111);

  // Tabs
  static const Color tabActiveBg = Color(0xFF000000);
  static const Color tabInactiveBg = Color(0xFFF2F2F2);
  static const Color tabActiveText = Color(0xFFFFFFFF);
  static const Color tabInactiveText = Color(0xFF9E9E9E);
  static const double tabHeight = 30;
  static const double tabHorizontalPadding = 10;
  static const double tabGap = 8;
  static const double tabBorderRadius = 10;

  // Grid
  static const double gridSpacing = 10;
  static const double gridRowSpacing = 16;
  static const double coverAspectRatio = 0.65;
}
