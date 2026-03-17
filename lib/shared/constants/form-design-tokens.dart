import 'package:flutter/material.dart';

abstract final class FormDesignTokens {
  // Field row
  static const double fieldRowHeight = 56;
  static const double fieldLabelWidth = 70;
  static const double fieldLabelSize = 14;
  static const double fieldValueSize = 14;
  static const double fieldIconGap = 14;
  static const double fieldLabelGap = 8;
  static const double fieldHintOpacity = 0.5;

  // Textarea
  static const double textareaSize = 14;
  static const double textareaLineHeight = 1.5;
  static const double textareaPadding = 16;
  static const int textareaMaxLines = 8;
  static const double textareaHintOpacity = 0.6;

  // Helper text
  static const double helperSize = 12;
  static const double helperLineHeight = 1.4;
  static const double helperHorizontalPadding = 4;

  // Submit button
  static const double buttonHeight = 50;
  static const double buttonFontSize = 16;
  static const FontWeight buttonFontWeight = FontWeight.w600;
  static const Color buttonBg = Color(0xFF0E0E0E);
  static const Color buttonText = Color(0xFFFFFFFF);

  // Divider
  static const double dividerIndent = 70;
  static const double dividerThickness = 1;
  static const Color dividerColor = Color(0xFFE8E4DF);
}
