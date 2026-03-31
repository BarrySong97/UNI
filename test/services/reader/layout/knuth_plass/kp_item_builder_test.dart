import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/layout/knuth_plass/paragraph_prepare_cache.dart';
import 'package:uni/services/reader/layout/knuth_plass/kp_item_builder.dart';
import 'package:uni/services/reader/layout/knuth_plass/kp_items.dart';
import 'package:uni/services/reader/layout/knuth_plass/width_cache.dart';
import 'package:uni/services/reader/models/reader_preferences.dart';
import 'package:uni/services/reader/models/render_node.dart';

void main() {
  group('KPItemBuilder', () {
    late ReaderPreferences prefs;
    late WidthCache widthCache;
    late ParagraphPrepareCache prepareCache;

    setUp(() {
      prefs = const ReaderPreferences();
      widthCache = WidthCache();
      prepareCache = ParagraphPrepareCache();
    });

    test('returns null for empty children', () {
      final result = KPItemBuilder.build(
        children: [],
        prefs: prefs,
        widthCache: widthCache,
      );
      expect(result, isNull);
    });

    test('single word produces box + finishing sequence', () {
      final children = [TextNode(content: 'Hello', nodeIndex: 0)];

      final items = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      expect(items, isNotNull);
      // Should have: Box("Hello") + finish Glue + finish Penalty
      expect(items!.length, 3);
      expect(items[0], isA<KPBox>());
      expect((items[0] as KPBox).text, 'Hello');
      expect(items[1], isA<KPGlue>());
      expect(items[2], isA<KPPenalty>());
      expect((items[2] as KPPenalty).cost, KPPenalty.minCost);
    });

    test('two words produce box-glue-box + finishing', () {
      final children = [TextNode(content: 'Hello world', nodeIndex: 0)];

      final items = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      expect(items, isNotNull);
      // Box("Hello") + Glue + Box("world") + finish Glue + finish Penalty
      expect(items!.length, 5);
      expect(items[0], isA<KPBox>());
      expect((items[0] as KPBox).text, 'Hello');
      expect(items[1], isA<KPGlue>());
      expect(items[2], isA<KPBox>());
      expect((items[2] as KPBox).text, 'world');
    });

    test('multiple TextNode children are processed sequentially', () {
      final children = [
        TextNode(content: 'Hello ', nodeIndex: 0),
        TextNode(content: 'bold world', nodeIndex: 6, bold: true),
      ];

      final items = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      expect(items, isNotNull);
      // Box("Hello") + Glue + Box("bold") + Glue + Box("world") + finishing
      final boxes = items!.whereType<KPBox>().toList();
      expect(boxes.length, 3);
      expect(boxes[0].text, 'Hello');
      expect(boxes[1].text, 'bold');
      expect(boxes[2].text, 'world');

      // "bold" and "world" should have bold style
      expect(boxes[1].style?.fontWeight, FontWeight.bold);
      expect(boxes[2].style?.fontWeight, FontWeight.bold);
    });

    test('LineBreakNode produces forced-break penalty', () {
      final children = [
        TextNode(content: 'Line1', nodeIndex: 0),
        const LineBreakNode(),
        TextNode(content: 'Line2', nodeIndex: 6),
      ];

      final items = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      expect(items, isNotNull);
      final penalties = items!
          .whereType<KPPenalty>()
          .where((p) => p.cost <= KPPenalty.minCost)
          .toList();
      // One from LineBreakNode + one from finishing sequence
      expect(penalties.length, 2);
    });

    test('box widths are positive', () {
      final children = [
        TextNode(content: 'Test word measurement', nodeIndex: 0),
      ];

      final items = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      expect(items, isNotNull);
      for (final item in items!) {
        if (item is KPBox) {
          expect(
            item.width,
            greaterThan(0.0),
            reason: 'Box "${item.text}" should have positive width',
          );
        }
      }
    });

    test('glue stretch and shrink match tex-linebreak values', () {
      final children = [TextNode(content: 'Two words', nodeIndex: 0)];

      final items = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      expect(items, isNotNull);
      // Filter out finishing glue (stretch = maxCost).
      final glues = items!
          .whereType<KPGlue>()
          .where((g) => g.stretch < KPPenalty.maxCost)
          .toList();
      expect(glues.isNotEmpty, isTrue);
      for (final g in glues) {
        // stretch = spaceWidth * 1.5
        expect(g.stretch, closeTo(g.width * 1.5, 0.01));
        // shrink = max(0, spaceWidth - 2)
        expect(g.shrink, closeTo(math.max(0.0, g.width - 2), 0.01));
      }
    });

    test('finishing glue has maxCost stretch', () {
      final children = [TextNode(content: 'Word', nodeIndex: 0)];

      final items = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      expect(items, isNotNull);
      // Second-to-last item should be finishing glue.
      final finishGlue = items![items.length - 2] as KPGlue;
      expect(finishGlue.width, 0.0);
      expect(finishGlue.stretch, KPPenalty.maxCost);
      expect(finishGlue.shrink, 0.0);
    });

    test('empty TextNode content is skipped', () {
      final children = [
        TextNode(content: '', nodeIndex: 0),
        TextNode(content: 'Word', nodeIndex: 1),
      ];

      final items = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      expect(items, isNotNull);
      final boxes = items!.whereType<KPBox>().toList();
      expect(boxes.length, 1);
      expect(boxes[0].text, 'Word');
    });

    test('heading level applies correct font scaling', () {
      final children = [TextNode(content: 'Title', nodeIndex: 0)];

      final itemsNormal = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      final widthCache2 = WidthCache();
      final itemsH1 = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache2,
        headingLevel: 1,
      );

      expect(itemsNormal, isNotNull);
      expect(itemsH1, isNotNull);

      final normalBox = itemsNormal!.whereType<KPBox>().first;
      final h1Box = itemsH1!.whereType<KPBox>().first;

      // H1 should be wider due to 2.0em scaling.
      expect(h1Box.width, greaterThan(normalBox.width));
    });

    test('CJK without spaces produces per-char breakable sequence', () {
      final children = [TextNode(content: '中文排版测试', nodeIndex: 0)];

      final items = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      expect(items, isNotNull);
      final boxes = items!.whereType<KPBox>().toList();
      final interCharGlue = items
          .whereType<KPGlue>()
          .where((g) => g.width == 0 && g.stretch < KPPenalty.maxCost)
          .toList();
      expect(boxes.length, equals('中文排版测试'.runes.length));
      expect(interCharGlue.length, greaterThan(0));
    });

    test('mixed Latin+CJK keeps Latin words and CJK char breaks', () {
      final children = [TextNode(content: 'Hello世界 test', nodeIndex: 0)];

      final items = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      expect(items, isNotNull);
      final boxes = items!.whereType<KPBox>().toList();
      expect(boxes.any((b) => b.text == 'Hello'), isTrue);
      expect(boxes.any((b) => b.text == '世'), isTrue);
      expect(boxes.any((b) => b.text == '界'), isTrue);
      expect(boxes.any((b) => b.text == 'test'), isTrue);

      final softPenalties = items
          .whereType<KPPenalty>()
          .where((p) => p.cost == 0)
          .toList();
      expect(softPenalties.isNotEmpty, isTrue);
    });

    test('soft hyphen emits discretionary penalty with hyphen width', () {
      final children = [
        TextNode(content: 'micro\u00adarchitecture', nodeIndex: 0),
      ];

      final items = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
      );

      expect(items, isNotNull);
      final boxes = items!.whereType<KPBox>().toList();
      expect(boxes.any((b) => b.text.contains('\u00ad')), isFalse);
      expect(boxes.any((b) => b.text == 'micro'), isTrue);
      expect(boxes.any((b) => b.text == 'architecture'), isTrue);

      final hyphenPenalties = items
          .whereType<KPPenalty>()
          .where((p) => p.flagged && p.width > 0)
          .toList();
      expect(hyphenPenalties.isNotEmpty, isTrue);
    });

    test('prepare cache reuses built items for same paragraph signature', () {
      final children = [TextNode(content: 'cache me once', nodeIndex: 0)];

      final first = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
        paragraphPrepareCache: prepareCache,
        availableWidth: 320,
      );
      final second = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
        paragraphPrepareCache: prepareCache,
        availableWidth: 320,
      );

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(identical(first, second), isTrue);
      expect(prepareCache.size, 1);
    });

    test('prepare cache key changes when available width changes', () {
      final children = [TextNode(content: 'width sensitive key', nodeIndex: 0)];

      final first = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
        paragraphPrepareCache: prepareCache,
        availableWidth: 300,
      );
      final second = KPItemBuilder.build(
        children: children,
        prefs: prefs,
        widthCache: widthCache,
        paragraphPrepareCache: prepareCache,
        availableWidth: 360,
      );

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(identical(first, second), isFalse);
      expect(prepareCache.size, 2);
    });
  });
}
