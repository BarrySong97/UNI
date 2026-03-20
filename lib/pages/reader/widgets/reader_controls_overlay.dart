import 'package:flutter/material.dart';

import '../../../services/reader/models/parsed_chapter.dart';
import '../../../services/reader/models/reader_preferences.dart';
import 'reader_font_panel.dart';
import 'reader_progress_panel.dart';
import 'reader_theme_panel.dart';
import 'reader_toc_panel.dart';

enum _ActivePanel { none, toc, progress, theme, font }

/// Reader controls overlay with a bottom icon toolbar.
///
/// Top bar slides down, bottom bar slides up on mount.
/// Tapping a toolbar button toggles the corresponding inline panel above
/// the toolbar. The panel slides up/down as a complete block.
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
    required this.toc,
    required this.chapters,
    required this.currentChapterIndex,
    required this.chapterTitleForPercent,
    required this.onChapterSelected,
    required this.onPercentChanged,
    this.onMorePressed,
  });

  final ReaderPreferences preferences;
  final String chapterTitle;
  final int currentPage;
  final int totalPages;
  final double bookPercent;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final ValueChanged<ReaderPreferences> onPreferencesChanged;
  final List<TocEntry> toc;
  final List<ParsedChapter> chapters;
  final int currentChapterIndex;
  final String Function(double percent) chapterTitleForPercent;
  final ValueChanged<int> onChapterSelected;
  final ValueChanged<double> onPercentChanged;
  final VoidCallback? onMorePressed;

  @override
  State<ReaderControlsOverlay> createState() => _ReaderControlsOverlayState();
}

class _ReaderControlsOverlayState extends State<ReaderControlsOverlay>
    with TickerProviderStateMixin {
  _ActivePanel _activePanel = _ActivePanel.none;

  /// Tracks which panel to render during close animation.
  _ActivePanel _renderedPanel = _ActivePanel.none;

  late final AnimationController _animController;
  late final Animation<Offset> _topSlide;
  late final Animation<Offset> _bottomSlide;

  late final AnimationController _panelAnimController;
  late final CurvedAnimation _panelCurve;

  ReaderPreferences get _prefs => widget.preferences;

  Color get _barColor =>
      _prefs.theme.isDark ? const Color(0xFF2A2A2A) : Colors.white;

  Color get _textColor => _prefs.theme.textColor;

  @override
  void initState() {
    super.initState();

    // Overlay slide-in animation.
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _topSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _bottomSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    // Panel slide animation.
    _panelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _panelCurve = CurvedAnimation(
      parent: _panelAnimController,
      curve: Curves.easeOut,
    );
    _panelAnimController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _renderedPanel = _ActivePanel.none);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _panelAnimController.dispose();
    super.dispose();
  }

  void _togglePanel(_ActivePanel panel) {
    if (_activePanel == panel) {
      // Close current panel.
      setState(() => _activePanel = _ActivePanel.none);
      _panelAnimController.reverse();
    } else {
      // Open or switch panel.
      final wasNone = _activePanel == _ActivePanel.none;
      setState(() {
        _activePanel = panel;
        _renderedPanel = panel;
      });
      if (wasNone) {
        _panelAnimController.forward();
      }
      // When switching panels (was already open), no animation — just swap content.
    }
  }

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

        // Top bar (slides down).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _topSlide,
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
                    onPressed: widget.onMorePressed,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom area: active panel + toolbar (slides up).
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _bottomSlide,
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
                    // Active panel — slides up from behind the toolbar.
                    AnimatedBuilder(
                      animation: _panelCurve,
                      builder: (context, child) {
                        final t = _panelCurve.value;
                        if (t == 0) return const SizedBox.shrink();
                        return ClipRect(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            heightFactor: t,
                            child: FractionalTranslation(
                              translation: Offset(0, 1.0 - t),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildRenderedPanel(),
                          Divider(
                            height: 1,
                            color: _textColor.withValues(alpha: 0.1),
                          ),
                        ],
                      ),
                    ),
                    // Bottom icon toolbar.
                    _buildToolbar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Active panel
  // ---------------------------------------------------------------------------

  Widget _buildRenderedPanel() {
    return switch (_renderedPanel) {
      _ActivePanel.toc => ReaderTocPanel(
        toc: widget.toc,
        chapters: widget.chapters,
        currentChapterIndex: widget.currentChapterIndex,
        preferences: _prefs,
        onChapterSelected: widget.onChapterSelected,
      ),
      _ActivePanel.progress => ReaderProgressPanel(
        bookPercent: widget.bookPercent,
        chapterTitleForPercent: widget.chapterTitleForPercent,
        preferences: _prefs,
        onPercentChanged: widget.onPercentChanged,
      ),
      _ActivePanel.theme => ReaderThemePanel(
        preferences: _prefs,
        onPreferencesChanged: widget.onPreferencesChanged,
      ),
      _ActivePanel.font => ReaderFontPanel(
        preferences: _prefs,
        onPreferencesChanged: widget.onPreferencesChanged,
      ),
      _ActivePanel.none => const SizedBox.shrink(),
    };
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
            icon: Icons.format_list_bulleted,
            isActive: _activePanel == _ActivePanel.toc,
            onTap: () => _togglePanel(_ActivePanel.toc),
          ),
          // 2. Annotation (placeholder)
          _toolbarButton(icon: Icons.border_color_outlined, onTap: () {}),
          // 3. Progress
          _toolbarButton(
            icon: Icons.data_usage_outlined,
            isActive: _activePanel == _ActivePanel.progress,
            onTap: () => _togglePanel(_ActivePanel.progress),
          ),
          // 4. Theme
          _toolbarButton(
            icon: Icons.brightness_medium_outlined,
            isActive: _activePanel == _ActivePanel.theme,
            onTap: () => _togglePanel(_ActivePanel.theme),
          ),
          // 5. Font settings
          _toolbarButton(
            icon: null,
            label: 'A',
            isActive: _activePanel == _ActivePanel.font,
            onTap: () => _togglePanel(_ActivePanel.font),
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
}
