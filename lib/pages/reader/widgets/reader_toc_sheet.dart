import 'package:flutter/material.dart';

import '../../../services/reader/models/parsed_chapter.dart';
import '../../../services/reader/models/reader_preferences.dart';

/// Bottom sheet showing the Table of Contents.
class ReaderTocSheet extends StatelessWidget {
  const ReaderTocSheet({
    super.key,
    required this.toc,
    required this.currentChapterIndex,
    required this.preferences,
    required this.onChapterSelected,
  });

  final List<TocEntry> toc;
  final int currentChapterIndex;
  final ReaderPreferences preferences;
  final ValueChanged<int> onChapterSelected;

  static Future<void> show({
    required BuildContext context,
    required List<TocEntry> toc,
    required int currentChapterIndex,
    required ReaderPreferences preferences,
    required ValueChanged<int> onChapterSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: preferences.theme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ReaderTocSheet(
        toc: toc,
        currentChapterIndex: currentChapterIndex,
        preferences: preferences,
        onChapterSelected: (index) {
          Navigator.of(context).pop();
          onChapterSelected(index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    final textColor = preferences.theme.textColor;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Table of Contents',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // TOC list.
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: toc.length,
              itemBuilder: (context, index) =>
                  _buildTocItem(toc[index], index, 0, textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTocItem(
    TocEntry entry,
    int chapterIndex,
    int depth,
    Color textColor,
  ) {
    final isCurrent = chapterIndex == currentChapterIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onChapterSelected(chapterIndex),
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
                      color: isCurrent ? Colors.blue : textColor,
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
          ...entry.children.asMap().entries.map(
            (e) => _buildTocItem(
              e.value,
              chapterIndex + e.key + 1,
              depth + 1,
              textColor,
            ),
          ),
      ],
    );
  }
}
