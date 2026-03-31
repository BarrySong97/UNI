import 'package:flutter/material.dart';

import '../../../services/reader/models/parsed_chapter.dart';
import '../../../services/reader/reader_href_matcher.dart';
import '../../../services/reader/models/reader_preferences.dart';

/// Inline panel showing the Table of Contents.
class ReaderTocPanel extends StatefulWidget {
  const ReaderTocPanel({
    super.key,
    required this.toc,
    required this.chapters,
    required this.currentChapterIndex,
    required this.preferences,
    required this.onChapterSelected,
  });

  final List<TocEntry> toc;
  final List<ParsedChapter> chapters;
  final int currentChapterIndex;
  final ReaderPreferences preferences;
  final ValueChanged<int> onChapterSelected;

  @override
  State<ReaderTocPanel> createState() => _ReaderTocPanelState();
}

class _ReaderTocPanelState extends State<ReaderTocPanel> {
  final GlobalKey _currentItemKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentChapter();
    });
  }

  void _scrollToCurrentChapter() {
    final keyContext = _currentItemKey.currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        alignment: 0.3,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  /// Build an href matcher for TOC-entry -> spine-index resolution.
  ReaderHrefIndex _buildHrefToSpineIndex() {
    return ReaderHrefIndex.fromChapters(widget.chapters);
  }

  /// Resolve a TOC entry's href to a spine index.
  int? _resolveSpineIndex(String tocHref, ReaderHrefIndex hrefIndex) {
    if (tocHref.isEmpty) return null;
    return hrefIndex.resolve(tocHref);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.5;
    final textColor = widget.preferences.theme.textColor;
    final hrefMap = _buildHrefToSpineIndex();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Table of Contents',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // TOC list.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in widget.toc)
                    _buildTocItem(entry, 0, textColor, hrefMap),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTocItem(
    TocEntry entry,
    int depth,
    Color textColor,
    ReaderHrefIndex hrefMap,
  ) {
    final spineIndex = _resolveSpineIndex(entry.href, hrefMap);
    final isCurrent =
        spineIndex != null && spineIndex == widget.currentChapterIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: isCurrent ? _currentItemKey : null,
          onTap: spineIndex != null
              ? () => widget.onChapterSelected(spineIndex)
              : null,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16.0 + depth * 20.0,
              right: 16,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: TextStyle(
                      color: isCurrent
                          ? Colors.blue
                          : spineIndex != null
                          ? textColor
                          : textColor.withValues(alpha: 0.4),
                      fontSize: 15,
                      fontWeight: isCurrent
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (isCurrent)
                  Icon(Icons.chevron_right, color: Colors.blue, size: 20),
              ],
            ),
          ),
        ),
        // Render nested children.
        if (entry.children.isNotEmpty)
          ...entry.children.map(
            (child) => _buildTocItem(child, depth + 1, textColor, hrefMap),
          ),
      ],
    );
  }
}
