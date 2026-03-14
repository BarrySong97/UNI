import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/reader/layout/knuth_plass/kp_items.dart';
import 'package:uni/services/reader/layout/knuth_plass/kp_solver.dart';

void main() {
  group('KPSolver', () {
    /// Helper: create a box with given width.
    KPBox box(double w) => KPBox(text: 'w', style: const TextStyle(), width: w);

    /// Helper: standard inter-word glue matching tex-linebreak values.
    KPGlue glue(double w) =>
        KPGlue(width: w, stretch: w * 1.5, shrink: w > 2 ? w - 2 : 0);

    /// Build a finishing sequence: fill glue + forced break.
    List<KPItem> finishing() => [
      const KPGlue(width: 0, stretch: KPPenalty.maxCost, shrink: 0),
      forcedBreak(),
    ];

    test('returns empty list for empty items', () {
      final breaks = KPSolver.solve([], 300.0);
      expect(breaks, isEmpty);
    });

    test('single word paragraph returns breakpoints', () {
      final items = <KPItem>[box(50.0), ...finishing()];

      final breaks = KPSolver.solve(items, 300.0);
      expect(breaks, isNotEmpty);
      // Should include start (0) and end (forced break) breakpoint.
      expect(breaks.length, greaterThanOrEqualTo(2));
      expect(breaks.first, 0);
    });

    test('two words that fit on one line produce two breakpoints', () {
      // "word1 word2" with total width 50+10+50 = 110 < 300
      final items = <KPItem>[box(50.0), glue(10.0), box(50.0), ...finishing()];

      final breaks = KPSolver.solve(items, 300.0);
      expect(breaks, isNotEmpty);
      // Start + end = 2 breakpoints, meaning 1 line.
      expect(breaks.length, 2);
    });

    test('words that exceed line width produce multiple lines', () {
      // 5 words of width 60 each, space 10, line width 200
      final items = <KPItem>[
        box(60.0),
        glue(10.0),
        box(60.0),
        glue(10.0),
        box(60.0),
        glue(10.0),
        box(60.0),
        glue(10.0),
        box(60.0),
        ...finishing(),
      ];

      final breaks = KPSolver.solve(items, 200.0);
      expect(breaks, isNotEmpty);
      // More than 2 breakpoints means more than 1 line.
      expect(breaks.length, greaterThan(2));
    });

    test('handles single word wider than line (emergency break)', () {
      final items = <KPItem>[
        box(500.0), // wider than line width
        ...finishing(),
      ];

      // Should not crash; emergency break handles this.
      final result = KPSolver.solve(items, 100.0);
      expect(result, isNotEmpty);
    });

    test('handles forced breaks (line break nodes)', () {
      // Two words with a forced break between them.
      final items = <KPItem>[
        box(50.0),
        forcedBreak(),
        box(50.0),
        ...finishing(),
      ];

      final breaks = KPSolver.solve(items, 300.0);
      expect(breaks, isNotEmpty);
      // At least 3 breakpoints: start, forced break, end.
      expect(breaks.length, greaterThanOrEqualTo(3));
    });

    test('breakpoints are sorted in ascending order', () {
      final items = <KPItem>[
        box(60.0),
        glue(10.0),
        box(60.0),
        glue(10.0),
        box(60.0),
        glue(10.0),
        box(60.0),
        glue(10.0),
        box(60.0),
        glue(10.0),
        box(60.0),
        ...finishing(),
      ];

      final breaks = KPSolver.solve(items, 150.0);
      expect(breaks, isNotEmpty);
      for (var i = 1; i < breaks.length; i++) {
        expect(breaks[i], greaterThan(breaks[i - 1]));
      }
    });

    test('many uniform words produce reasonable break distribution', () {
      // 10 words, each 30px, space 10px, line width 200
      final items = <KPItem>[];
      for (var i = 0; i < 10; i++) {
        if (i > 0) items.add(glue(10.0));
        items.add(box(30.0));
      }
      items.addAll(finishing());

      final breaks = KPSolver.solve(items, 200.0);
      expect(breaks, isNotEmpty);
      expect(breaks.length, greaterThan(2));
    });

    test('throws MaxAdjustmentExceededError when maxAdjustmentRatio is set', () {
      // Two words that need significant stretching to fill the line.
      // No finishing glue — so the solver cannot absorb slack.
      // With low maxAdjustmentRatio and initialMaxAdjustmentRatio matching it,
      // the solver should throw.
      final items = <KPItem>[
        box(10.0),
        KPGlue(width: 5.0, stretch: 2.0, shrink: 1.0),
        box(10.0),
        // Forced break at end (no finishing glue to absorb slack).
        forcedBreak(),
      ];

      expect(
        () => KPSolver.solve(
          items,
          300.0,
          const KPOptions(
            maxAdjustmentRatio: 0.5,
            initialMaxAdjustmentRatio: 0.5,
          ),
        ),
        throwsA(isA<MaxAdjustmentExceededError>()),
      );
    });

    test(
      'retries with higher threshold when initialMaxAdjustmentRatio is low',
      () {
        // Words need some stretching. initialMaxAdjustmentRatio = 0.1 is too low
        // but maxAdjustmentRatio = null allows retry.
        final items = <KPItem>[
          box(80.0),
          glue(10.0),
          box(80.0),
          ...finishing(),
        ];

        // Should not throw — retry finds a solution.
        final breaks = KPSolver.solve(
          items,
          300.0,
          const KPOptions(initialMaxAdjustmentRatio: 0.1),
        );
        expect(breaks, isNotEmpty);
      },
    );

    test('does not lose optimum when negative values are present', () {
      // Ported from tex-linebreak layout-test: Restriction-1 guard case.
      final items = <KPItem>[
        box(12.0),
        const KPGlue(width: 0.0, stretch: 0.0, shrink: 2.0),
        box(-2.0),
        const KPGlue(width: 0.0, stretch: 0.0, shrink: 0.0),
        box(9.0),
        const KPGlue(width: 0.0, stretch: 3.0, shrink: 0.0),
        forcedBreak(),
      ];

      final breaks = KPSolver.solve(items, 10.0);
      expect(breaks, equals([0, 3, 6]));
    });
  });

  group('KPSolver.adjustmentRatios', () {
    KPBox box(double w) => KPBox(text: 'w', style: const TextStyle(), width: w);
    KPGlue glue(double w) =>
        KPGlue(width: w, stretch: w * 1.5, shrink: w > 2 ? w - 2 : 0);
    List<KPItem> finishing() => [
      const KPGlue(width: 0, stretch: KPPenalty.maxCost, shrink: 0),
      forcedBreak(),
    ];

    test('perfect fit returns zero ratio', () {
      // Two words filling exactly the line: 45 + 10 + 45 = 100
      final items = <KPItem>[box(45.0), glue(10.0), box(45.0), ...finishing()];

      final breaks = KPSolver.solve(items, 100.0);
      final ratios = KPSolver.adjustmentRatios(items, 100.0, breaks);
      expect(ratios, isNotEmpty);
      // First line should be close to zero (perfect fit).
      expect(ratios[0].abs(), lessThan(0.01));
    });

    test('returns one ratio per line', () {
      final items = <KPItem>[
        box(60.0),
        glue(10.0),
        box(60.0),
        glue(10.0),
        box(60.0),
        ...finishing(),
      ];

      final breaks = KPSolver.solve(items, 150.0);
      final ratios = KPSolver.adjustmentRatios(items, 150.0, breaks);
      // Number of ratios = number of breakpoints - 1 = number of lines.
      expect(ratios.length, breaks.length - 1);
    });
  });

  group('KPSolver.positionItems', () {
    KPBox box(double w) => KPBox(text: 'w', style: const TextStyle(), width: w);
    KPGlue glue(double w, double shrink, double stretch) =>
        KPGlue(width: w, stretch: stretch, shrink: shrink);

    test('lays out items with justified margins', () {
      final items = <KPItem>[
        box(10.0),
        glue(10.0, 5.0, 5.0),
        box(10.0),
        glue(10.0, 5.0, 5.0),
        box(10.0),
        glue(10.0, 5.0, 5.0),
        forcedBreak(),
      ];
      final positioned = KPSolver.positionItems(items, 35.0, [0, 3, 6]);

      expect(positioned.length, 3);
      expect(positioned[0].item, 0);
      expect(positioned[0].line, 0);
      expect(positioned[0].xOffset, closeTo(0.0, 0.001));
      expect(positioned[0].width, closeTo(10.0, 0.001));

      expect(positioned[1].item, 2);
      expect(positioned[1].line, 0);
      expect(positioned[1].xOffset, closeTo(25.0, 0.001));
      expect(positioned[1].width, closeTo(10.0, 0.001));

      expect(positioned[2].item, 4);
      expect(positioned[2].line, 1);
      expect(positioned[2].xOffset, closeTo(0.0, 0.001));
      expect(positioned[2].width, closeTo(10.0, 0.001));
    });

    test('does not let gap shrink below glue.width - glue.shrink', () {
      final items = <KPItem>[
        box(10.0),
        glue(10.0, 5.0, 5.0),
        box(100.0),
        forcedBreak(),
      ];
      final positioned = KPSolver.positionItems(items, 50.0, [0, 3]);

      expect(positioned.length, 2);
      expect(positioned[0].item, 0);
      expect(positioned[0].xOffset, closeTo(0.0, 0.001));
      expect(positioned[1].item, 2);
      expect(positioned[1].xOffset, closeTo(15.0, 0.001));
    });
  });
}
