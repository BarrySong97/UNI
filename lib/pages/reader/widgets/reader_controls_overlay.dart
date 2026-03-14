import 'package:flutter/material.dart';

import '../../../services/reader/models/reader_preferences.dart';
import 'reader_font_panel.dart';

/// Reader controls overlay with a bottom icon toolbar.
///
/// Tapping the "A" (font) button toggles a settings panel above the toolbar
/// for adjusting font size, margins, line spacing, and font family.
class ReaderControlsOverlay extends StatefulWidget {
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

  @override
  State<ReaderControlsOverlay> createState() => _ReaderControlsOverlayState();
}

class _ReaderControlsOverlayState extends State<ReaderControlsOverlay> {
  bool _showFontPanel = false;

  ReaderPreferences get _prefs => widget.preferences;

  Color get _barColor => _prefs.theme == ReaderTheme.dark
      ? const Color(0xFF2A2A2A)
      : Colors.white;

  Color get _textColor => _prefs.theme.textColor;

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.of(context).padding;

    return Stack(
      children: [
        // Backdrop: closes overlay on tap.
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.transparent),
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
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: _textColor, size: 22),
                  onPressed: widget.onBack,
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.more_horiz, color: _textColor, size: 22),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),

        // Bottom area: font panel + toolbar.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: _barColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Font settings panel (collapsible).
                  if (_showFontPanel)
                    ReaderFontPanel(
                      preferences: _prefs,
                      onPreferencesChanged: widget.onPreferencesChanged,
                    ),
                  // Divider above toolbar when panel is open.
                  if (_showFontPanel)
                    Divider(
                      height: 1,
                      color: _textColor.withValues(alpha: 0.1),
                    ),
                  // Bottom icon toolbar.
                  _buildToolbar(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom toolbar with 5 icons
  // ---------------------------------------------------------------------------

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. TOC
          _toolbarButton(
            icon: Icons.menu,
            onTap: widget.onTocPressed,
          ),
          // 2. Annotation (placeholder)
          _toolbarButton(
            icon: Icons.edit_off_outlined,
            onTap: () {},
          ),
          // 3. Progress
          _toolbarButton(
            icon: Icons.linear_scale,
            onTap: () {},
          ),
          // 4. Theme
          _toolbarButton(
            icon: Icons.light_mode_outlined,
            onTap: _cycleTheme,
          ),
          // 5. Font settings
          _toolbarButton(
            icon: null,
            label: 'A',
            isActive: _showFontPanel,
            onTap: () => setState(() => _showFontPanel = !_showFontPanel),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({
    IconData? icon,
    String? label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    final color = isActive ? Colors.blue : _textColor.withValues(alpha: 0.75);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 52,
        height: 44,
        child: Center(
          child: icon != null
              ? Icon(icon, color: color, size: 24)
              : Text(
                  label!,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Theme cycling
  // ---------------------------------------------------------------------------

  void _cycleTheme() {
    final themes = ReaderTheme.values;
    final currentIndex = themes.indexOf(_prefs.theme);
    final next = themes[(currentIndex + 1) % themes.length];
    widget.onPreferencesChanged(_prefs.copyWith(theme: next));
  }
}
