import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/reader/widgets/reader_toc_panel.dart';
import 'package:uni/services/reader/models/parsed_chapter.dart';
import 'package:uni/services/reader/models/reader_preferences.dart';

void main() {
  testWidgets(
    'TOC entry resolves to chapter index with normalized href match',
    (tester) async {
      int? selectedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderTocPanel(
              toc: const [
                TocEntry(title: 'Content', href: 'xhtml/content.xhtml#toc'),
              ],
              chapters: const [
                ParsedChapter(
                  index: 5,
                  title: 'Chapter 5',
                  href: '/OEBPS/xhtml/chapter5.xhtml',
                  nodes: [],
                ),
                ParsedChapter(
                  index: 6,
                  title: 'Content',
                  href: '/OEBPS/xhtml/content.xhtml',
                  nodes: [],
                ),
              ],
              currentChapterIndex: 5,
              preferences: const ReaderPreferences(),
              onChapterSelected: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Content'));
      await tester.pump();

      expect(selectedIndex, 6);
    },
  );
}
