import 'dart:ui' show Canvas, Color, Paint, PictureRecorder, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/layout/reader_layout_engine.dart';
import 'package:uni/services/reader/models/reader_preferences.dart';
import 'package:uni/services/reader/models/render_node.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const engine = ReaderLayoutEngine();
  const prefs = ReaderPreferences(
    baseFontSizePx: 16,
    pageHorizontalPaddingPx: 0,
    pageVerticalPaddingPx: 0,
  );

  test('paragraph first line stays aligned (no mixed indent)', () {
    final chapter = engine.paginate(
      chapterIndex: 0,
      nodes: [
        const ParagraphNode(
          textIndentEm: 2.0,
          children: [
            TextNode(
              content:
                  'This paragraph is intentionally very long so it wraps into multiple lines and lets us verify first-line alignment normalization behavior in the reader layout engine.',
            ),
          ],
        ),
      ],
      viewportSize: const Size(140, 400),
      prefs: prefs,
    );

    final textElements = chapter.pages.first.elements
        .where((e) => e.textPainter != null)
        .toList();

    expect(textElements.length, 1);
    expect(
      textElements.first.textPainter!.computeLineMetrics().length,
      greaterThanOrEqualTo(2),
    );
    expect(textElements.first.rect.left, 0);
  });

  test('paragraph split keeps background on every page fragment', () {
    final chapter = engine.paginate(
      chapterIndex: 0,
      nodes: [
        const ParagraphNode(
          backgroundColor: 0xFFEFEFEF,
          children: [
            TextNode(
              content:
                  'Background paragraph. Background paragraph. Background paragraph. Background paragraph. '
                  'Background paragraph. Background paragraph. Background paragraph. Background paragraph. '
                  'Background paragraph. Background paragraph. Background paragraph. Background paragraph. '
                  'Background paragraph. Background paragraph. Background paragraph. Background paragraph. '
                  'Background paragraph. Background paragraph. Background paragraph. Background paragraph. ',
            ),
          ],
        ),
      ],
      viewportSize: const Size(220, 120),
      prefs: prefs,
    );

    expect(chapter.pages.length, greaterThan(1));
    for (final page in chapter.pages) {
      final hasBackground = page.elements.any((e) => e.backgroundPaint != null);
      expect(hasBackground, isTrue);
    }
  });

  test('list style markers are applied with fallback', () {
    String markerTextForStyle(String? style) {
      final chapter = engine.paginate(
        chapterIndex: 0,
        nodes: [
          ListNode(
            ordered: true,
            listStyle: style,
            items: const [
              ListItemNode(children: [TextNode(content: 'Alpha')]),
            ],
          ),
        ],
        viewportSize: const Size(300, 300),
        prefs: prefs,
      );
      // Marker is now a separate element from the text content.
      final markers = chapter.pages.first.elements
          .where((e) => e.textPainter != null)
          .map((e) => e.textPainter!.text!.toPlainText())
          .toList();
      // First text element is the body text, marker is placed after it.
      return markers.firstWhere((t) => !t.contains('Alpha'));
    }

    expect(markerTextForStyle('decimal'), equals('1.'));
    expect(markerTextForStyle('lower-alpha'), equals('a.'));
    expect(markerTextForStyle('upper-roman'), equals('I.'));
    expect(markerTextForStyle('unknown-style'), equals('1.'));
  });

  test('nested list uses deeper indentation than parent list', () {
    final chapter = engine.paginate(
      chapterIndex: 0,
      nodes: [
        const ListNode(
          ordered: false,
          items: [
            ListItemNode(
              children: [TextNode(content: 'Parent')],
              subNodes: [
                ListNode(
                  ordered: false,
                  items: [
                    ListItemNode(children: [TextNode(content: 'Child')]),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      viewportSize: const Size(300, 300),
      prefs: prefs,
    );

    final textElements = chapter.pages.first.elements
        .where((e) => e.textPainter != null)
        .toList();
    final parent = textElements.firstWhere(
      (e) => e.textPainter!.text!.toPlainText().contains('Parent'),
    );
    final child = textElements.firstWhere(
      (e) => e.textPainter!.text!.toPlainText().contains('Child'),
    );
    expect(child.rect.left, greaterThan(parent.rect.left));
  });

  test('oversized table row is continued across pages without overflow', () {
    final chapter = engine.paginate(
      chapterIndex: 0,
      nodes: const [
        TableNode(
          rows: [
            TableRowNode(
              cells: [
                TableCellNode(
                  children: [
                    TextNode(
                      content:
                          'Oversized row cell content. Oversized row cell content. Oversized row cell content. '
                          'Oversized row cell content. Oversized row cell content. Oversized row cell content. '
                          'Oversized row cell content. Oversized row cell content. Oversized row cell content.',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      viewportSize: const Size(260, 120),
      prefs: prefs,
    );

    expect(chapter.pages.length, greaterThan(1));
    for (final page in chapter.pages) {
      for (final element in page.elements) {
        expect(element.rect.bottom, lessThanOrEqualTo(120.001));
      }
    }
  });

  test('nested image nodes can resolve to pre-decoded images', () async {
    const imageBase64Key = 'nested-image-key';
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0xFF000000),
    );
    final image = await recorder.endRecording().toImage(1, 1);

    final chapter = engine.paginate(
      chapterIndex: 0,
      nodes: [
        const ListNode(
          ordered: false,
          items: [
            ListItemNode(
              children: [TextNode(content: 'item')],
              subNodes: [
                ImageNode(dataBase64: imageBase64Key, widthPx: 1, heightPx: 1),
              ],
            ),
          ],
        ),
      ],
      viewportSize: const Size(180, 200),
      prefs: prefs,
      decodedImages: {imageBase64Key.hashCode.toString(): image},
    );

    final hasRenderedImage = chapter.pages.any(
      (p) => p.elements.any((e) => e.image != null),
    );
    expect(hasRenderedImage, isTrue);
  });
}
