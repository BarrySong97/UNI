import 'package:flutter/material.dart';

import '../../../services/reader/models/reader_preferences.dart';

/// Inline panel displaying theme color swatches for the reader.
class ReaderThemePanel extends StatelessWidget {
  const ReaderThemePanel({
    super.key,
    required this.preferences,
    required this.onPreferencesChanged,
  });

  final ReaderPreferences preferences;
  final ValueChanged<ReaderPreferences> onPreferencesChanged;

  @override
  Widget build(BuildContext context) {
    final themes = ReaderTheme.values;
    // Split into rows of 4.
    final firstRow = themes.take(4).toList();
    final secondRow = themes.skip(4).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(firstRow),
          const SizedBox(height: 12),
          _buildRow(secondRow),
        ],
      ),
    );
  }

  Widget _buildRow(List<ReaderTheme> themes) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: themes.map((theme) => _buildSwatch(theme)).toList(),
    );
  }

  Widget _buildSwatch(ReaderTheme theme) {
    final isSelected = preferences.theme == theme;
    final textColor = preferences.theme.textColor;

    return GestureDetector(
      onTap: () => onPreferencesChanged(preferences.copyWith(theme: theme)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Aa',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            theme.name,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.blue : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
