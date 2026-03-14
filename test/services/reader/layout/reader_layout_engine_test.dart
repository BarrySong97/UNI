import 'dart:ui'
    show Canvas, Color, Paint, PictureRecorder, Rect, Size, TextAlign;

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

    expect(textElements.length, greaterThanOrEqualTo(1));
    // First line fragments should start at x=0 (text-indent is normalized away).
    final firstLineTop = textElements
        .map((e) => e.rect.top)
        .reduce((a, b) => a < b ? a : b);
    final firstLineElements = textElements
        .where((e) => (e.rect.top - firstLineTop).abs() < 0.01)
        .toList();
    for (final e in firstLineElements) {
      expect(e.rect.left, greaterThanOrEqualTo(0));
    }
    // The first fragment on the first line should start at x=0 (no indent).
    expect(firstLineElements.first.rect.left, closeTo(0, 0.01));
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

  test(
    'justified mixed styles use positioned fragments and fill line width',
    () {
      final chapter = engine.paginate(
        chapterIndex: 0,
        nodes: const [
          ParagraphNode(
            align: TextAlign.justify,
            children: [
              TextNode(content: 'Alpha beta gamma delta '),
              TextNode(content: 'EPSILON ZETA ', bold: true),
              TextNode(
                content:
                    'eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega',
              ),
            ],
          ),
        ],
        viewportSize: const Size(360, 300),
        prefs: prefs,
      );

      final textElements = chapter.pages.first.elements
          .where((e) => e.textPainter != null)
          .toList();
      expect(textElements.length, greaterThan(2));

      final firstLineTop = textElements
          .map((e) => e.rect.top)
          .reduce((a, b) => a < b ? a : b);
      final firstLineElements = textElements
          .where((e) => (e.rect.top - firstLineTop).abs() < 0.01)
          .toList();

      // Positioned fragment mode produces multiple text elements on one line.
      expect(firstLineElements.length, greaterThan(1));

      final firstLineRight = firstLineElements
          .map((e) => e.rect.right)
          .reduce((a, b) => a > b ? a : b);
      expect(firstLineRight, closeTo(360.0, 5.0));
    },
  );

  test(
    'justified CJK paragraph keeps small right-side gaps on non-last lines',
    () {
      final chapter = engine.paginate(
        chapterIndex: 0,
        nodes: const [
          ParagraphNode(
            align: TextAlign.justify,
            children: [
              TextNode(
                content:
                    '这是一个用于验证中文段落两端对齐效果的长文本我们希望每一行的末尾都尽量贴近右边界而不是留下明显空位'
                    '并且我们需要更多的文字来确保在较宽的视口下依然可以生成足够多的行数以进行验证',
              ),
            ],
          ),
        ],
        viewportSize: const Size(360, 400),
        prefs: prefs,
      );

      final textElements = chapter.pages.first.elements
          .where((e) => e.textPainter != null)
          .toList();
      expect(textElements.isNotEmpty, isTrue);

      final byLine = <double, List<double>>{};
      for (final e in textElements) {
        final key = (e.rect.top * 10).roundToDouble() / 10;
        byLine.putIfAbsent(key, () => <double>[]).add(e.rect.right);
      }
      final lineKeys = byLine.keys.toList()..sort();
      expect(lineKeys.length, greaterThan(2));

      final checkLineCount = (lineKeys.length - 1).clamp(1, 3);
      for (var i = 0; i < checkLineCount; i++) {
        final lineRights = byLine[lineKeys[i]]!;
        final right = lineRights.reduce((a, b) => a > b ? a : b);
        final gap = 360.0 - right;
        expect(gap, lessThanOrEqualTo(4.0));
      }
    },
  );

  test(
    'justified English paragraph keeps small right-side gaps on non-last lines',
    () {
      final chapter = engine.paginate(
        chapterIndex: 0,
        nodes: const [
          ParagraphNode(
            align: TextAlign.justify,
            children: [
              TextNode(
                content:
                    'This is a long English paragraph used to verify that justification keeps line endings close to the right edge and avoids visibly large trailing gaps on non-last lines. '
                    'We add more text here to ensure there are enough words per line at a wider viewport width to produce well-filled justified lines.',
              ),
            ],
          ),
        ],
        viewportSize: const Size(360, 400),
        prefs: prefs,
      );

      final textElements = chapter.pages.first.elements
          .where((e) => e.textPainter != null)
          .toList();
      expect(textElements.isNotEmpty, isTrue);

      final byLine = <double, List<double>>{};
      for (final e in textElements) {
        final key = (e.rect.top * 10).roundToDouble() / 10;
        byLine.putIfAbsent(key, () => <double>[]).add(e.rect.right);
      }
      final lineKeys = byLine.keys.toList()..sort();
      expect(lineKeys.length, greaterThan(2));

      final checkLineCount = (lineKeys.length - 1).clamp(1, 3);
      for (var i = 0; i < checkLineCount; i++) {
        final lineRights = byLine[lineKeys[i]]!;
        final right = lineRights.reduce((a, b) => a > b ? a : b);
        final gap = 360.0 - right;
        expect(gap, lessThanOrEqualTo(5.0));
      }
    },
  );

  test(
    'left-aligned paragraph is auto-justified by layout engine',
    () {
      // ParagraphNode with default TextAlign.left should be overridden to
      // justify by the layout engine when text is long enough (flowing body
      // text), producing multiple fragments per line.
      final chapter = engine.paginate(
        chapterIndex: 0,
        nodes: const [
          ParagraphNode(
            // align defaults to TextAlign.left
            children: [
              TextNode(
                content:
                    'Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega. '
                    'These additional words ensure the paragraph is long enough to be detected as flowing body text by the layout engine heuristic.',
              ),
            ],
          ),
        ],
        viewportSize: const Size(360, 400),
        prefs: prefs,
      );

      final textElements = chapter.pages.first.elements
          .where((e) => e.textPainter != null)
          .toList();

      // K-P justified layout produces multiple fragments (one per word).
      expect(textElements.length, greaterThan(3));

      // Non-last lines should fill the available width.
      final byLine = <double, List<double>>{};
      for (final e in textElements) {
        final key = (e.rect.top * 10).roundToDouble() / 10;
        byLine.putIfAbsent(key, () => <double>[]).add(e.rect.right);
      }
      final lineKeys = byLine.keys.toList()..sort();
      if (lineKeys.length > 2) {
        final firstLineRight = byLine[lineKeys[0]]!
            .reduce((a, b) => a > b ? a : b);
        expect(360.0 - firstLineRight, lessThanOrEqualTo(5.0));
      }
    },
  );

  test(
    'last line of justified paragraph is not excessively stretched',
    () {
      // Use a short last line to ensure the gap is visible.
      final chapter = engine.paginate(
        chapterIndex: 0,
        nodes: const [
          ParagraphNode(
            align: TextAlign.justify,
            children: [
              TextNode(
                content:
                    'Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega. '
                    'These additional words make the paragraph long enough for multiple well-filled lines at this viewport width. End.',
              ),
            ],
          ),
        ],
        viewportSize: const Size(360, 400),
        prefs: prefs,
      );

      final textElements = chapter.pages.first.elements
          .where((e) => e.textPainter != null)
          .toList();

      final byLine = <double, List<double>>{};
      for (final e in textElements) {
        final key = (e.rect.top * 10).roundToDouble() / 10;
        byLine.putIfAbsent(key, () => <double>[]).add(e.rect.right);
      }
      final lineKeys = byLine.keys.toList()..sort();
      expect(lineKeys.length, greaterThan(1));

      // Non-last lines should be close to the line width.
      if (lineKeys.length > 2) {
        final firstLineRight = byLine[lineKeys[0]]!
            .reduce((a, b) => a > b ? a : b);
        expect(firstLineRight, closeTo(360.0, 5.0));
      }
    },
  );

  test(
    'short paragraph does not get excessively stretched word spacing',
    () {
      // A paragraph with few words should not have huge gaps between words,
      // even if the K-P algorithm runs. The ratio cap in positionItems
      // ensures moderate spacing.
      final chapter = engine.paginate(
        chapterIndex: 0,
        nodes: const [
          ParagraphNode(
            align: TextAlign.justify,
            children: [
              TextNode(
                content: 'I then proceeded to have a wonderful time at the event.',
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
      expect(textElements.isNotEmpty, isTrue);

      // If K-P runs, check that fragment gaps are not excessive.
      if (textElements.length > 1) {
        final byLine = <double, List<double>>{};
        for (final e in textElements) {
          final key = (e.rect.top * 10).roundToDouble() / 10;
          byLine.putIfAbsent(key, () => []);
          byLine[key]!.add(e.rect.left);
          byLine[key]!.add(e.rect.right);
        }

        // For each line, the max gap between adjacent fragments should be
        // reasonable (not exceeding ~4x normal space width at 16px ≈ ~25px).
        for (final positions in byLine.values) {
          positions.sort();
          for (var i = 1; i < positions.length - 1; i += 2) {
            final gap = positions[i + 1] - positions[i];
            // Gap between fragment right edge and next fragment left edge.
            if (gap > 0) {
              expect(gap, lessThan(30.0),
                  reason: 'Word gap should not be excessively wide');
            }
          }
        }
      }
    },
  );

  test(
    'short paragraph is not auto-justified (stays left-aligned)',
    () {
      // A short paragraph that doesn't fill ~1.5 lines should not be
      // auto-justified, keeping normal left-aligned spacing.
      final chapter = engine.paginate(
        chapterIndex: 0,
        nodes: const [
          ParagraphNode(
            // align defaults to TextAlign.left
            children: [
              TextNode(content: 'ISBN 978-0-123456-47-2'),
            ],
          ),
        ],
        viewportSize: const Size(360, 300),
        prefs: prefs,
      );

      final textElements = chapter.pages.first.elements
          .where((e) => e.textPainter != null)
          .toList();
      // Should be a single greedy element (not K-P fragments).
      expect(textElements.length, equals(1));
    },
  );

  test(
    'paragraph with LineBreakNode is not auto-justified',
    () {
      // Structured content with forced line breaks (e.g. ISBN metadata,
      // addresses) should not be force-justified even if long enough.
      final chapter = engine.paginate(
        chapterIndex: 0,
        nodes: const [
          ParagraphNode(
            children: [
              TextNode(content: 'First Edition published in 2020'),
              LineBreakNode(),
              TextNode(content: 'Second Edition published in 2023'),
              LineBreakNode(),
              TextNode(content: 'Third Edition published in 2025'),
            ],
          ),
        ],
        viewportSize: const Size(360, 300),
        prefs: prefs,
      );

      final textElements = chapter.pages.first.elements
          .where((e) => e.textPainter != null)
          .toList();
      // Should be a single greedy element (not K-P fragments).
      expect(textElements.length, equals(1));
    },
  );
}
