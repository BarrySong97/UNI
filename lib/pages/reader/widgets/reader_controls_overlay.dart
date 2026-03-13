import 'package:flutter/material.dart';

import '../../../services/reader/models/reader_preferences.dart';

/// Top and bottom bars shown when the user taps the center of the reader.
class ReaderControlsOverlay extends StatelessWidget {
  const ReaderControlsOverlay({
    super.key,
    required this.preferences,
    required this.chapterTitle,
    required this.currentPage,
    required this.totalPages,
    required this.bookPercent,
    required this.onClose,
    required this.onBack,
    required this.onPreferencesChanged,
    required this.onTocPressed,
  });

  final ReaderPreferences preferences;
  final String chapterTitle;
  final int currentPage;
  final int totalPages;
  final double bookPercent;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final ValueChanged<ReaderPreferences> onPreferencesChanged;
  final VoidCallback onTocPressed;

  Color get _barColor => preferences.theme == ReaderTheme.dark
      ? const Color(0xFF2A2A2A)
      : Colors.white;

  Color get _textColor => preferences.theme.textColor;

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.of(context).padding;

    return Stack(
      children: [
        // Backdrop.
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(color: Colors.black26),
          ),
        ),

        // Top bar.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: mediaPadding.top + 8,
              left: 4,
              right: 4,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: _barColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: _textColor),
                  onPressed: onBack,
                ),
                Expanded(
                  child: Text(
                    chapterTitle,
                    style: TextStyle(color: _textColor, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.list, color: _textColor),
                  onPressed: onTocPressed,
                ),
              ],
            ),
          ),
        ),

        // Bottom bar.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              bottom: mediaPadding.bottom + 12,
              left: 16,
              right: 16,
              top: 12,
            ),
            decoration: BoxDecoration(
              color: _barColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar.
                _buildProgressBar(),
                const SizedBox(height: 12),
                // Font size controls.
                _buildFontSizeControls(),
                const SizedBox(height: 8),
                // Theme selector.
                _buildThemeSelector(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        Text(
          '${currentPage + 1}',
          style: TextStyle(color: _textColor, fontSize: 12),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LinearProgressIndicator(
              value: totalPages > 0 ? (currentPage + 1) / totalPages : 0,
              backgroundColor: _textColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                _textColor.withValues(alpha: 0.5),
              ),
              minHeight: 3,
            ),
          ),
        ),
        Text('$totalPages', style: TextStyle(color: _textColor, fontSize: 12)),
      ],
    );
  }

  Widget _buildFontSizeControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.text_decrease, color: _textColor),
          onPressed: preferences.baseFontSizePx > 12
              ? () => onPreferencesChanged(
                  preferences.copyWith(
                    baseFontSizePx: preferences.baseFontSizePx - 1,
                  ),
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${preferences.baseFontSizePx.round()}',
            style: TextStyle(color: _textColor, fontSize: 16),
          ),
        ),
        IconButton(
          icon: Icon(Icons.text_increase, color: _textColor),
          onPressed: preferences.baseFontSizePx < 32
              ? () => onPreferencesChanged(
                  preferences.copyWith(
                    baseFontSizePx: preferences.baseFontSizePx + 1,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildThemeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ReaderTheme.values.map((theme) {
        final isSelected = preferences.theme == theme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () =>
                onPreferencesChanged(preferences.copyWith(theme: theme)),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade400,
                  width: isSelected ? 2.5 : 1.0,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
