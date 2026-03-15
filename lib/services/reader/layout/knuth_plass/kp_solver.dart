import 'dart:math' as math;

import 'kp_items.dart';

/// Parameters for the Knuth-Plass line-breaking algorithm.
///
/// Mirrors the `Options` interface from tex-linebreak.
class KPOptions {
  const KPOptions({
    this.maxAdjustmentRatio,
    this.initialMaxAdjustmentRatio = 1.0,
    this.doubleHyphenPenalty = 0.0,
    this.adjacentLooseTightPenalty = 0.0,
  });

  /// Maximum adjustment ratio for stretching glue.
  ///
  /// If `null`, lines are stretched as far as necessary (no limit).
  /// If non-null and exceeded, a [MaxAdjustmentExceededError] is thrown so
  /// the caller can retry with hyphenation.
  final double? maxAdjustmentRatio;

  /// The starting maximum adjustment ratio for the first attempt.
  /// The solver retries with `ratio * 2` when the active set empties.
  final double initialMaxAdjustmentRatio;

  /// Extra demerits for two consecutive lines ending with flagged breaks
  /// (e.g. hyphens).
  final double doubleHyphenPenalty;

  /// Extra demerits for adjacent lines whose fitness classes differ by more
  /// than 1.
  final double adjacentLooseTightPenalty;
}

/// Thrown when `maxAdjustmentRatio` is exceeded and no feasible solution can
/// be found within the threshold. The caller should retry with hyphenation.
class MaxAdjustmentExceededError implements Exception {
  const MaxAdjustmentExceededError();
  @override
  String toString() => 'MaxAdjustmentExceededError';
}

/// Positioned output item from [KPSolver.positionItems].
class KPPositionedItem {
  const KPPositionedItem({
    required this.item,
    required this.line,
    required this.xOffset,
    required this.width,
  });

  /// Index in the source `items` array.
  final int item;

  /// Line number (0-based).
  final int line;

  /// X offset in logical pixels.
  final double xOffset;

  /// Render width in logical pixels.
  final double width;
}

const _minAdjustmentRatio = -1.0;

/// Maximum stretch ratio applied when rendering non-last lines.
/// Prevents visually jarring wide word spacing on lines with few words.
const _maxVisualRatio = 2.0;

bool _isForcedBreak(KPItem item) =>
    item is KPPenalty && item.cost <= KPPenalty.minCost;

/// Internal node in the active-node linked list.
class _Node {
  _Node({
    required this.index,
    required this.line,
    required this.fitness,
    required this.totalWidth,
    required this.totalStretch,
    required this.totalShrink,
    required this.totalDemerits,
    this.prev,
  });

  /// Item index where this break occurs.
  final int index;

  /// Line number — the line that *ends* at this break.
  final int line;

  /// Fitness class of the line ending at this break (0-3).
  final int fitness;

  /// Running sums up to the first box (or forced break) after this break,
  /// for correct subtraction-based line width calculation.
  final double totalWidth;
  final double totalStretch;
  final double totalShrink;

  /// Accumulated demerits from the start up to this break.
  final double totalDemerits;

  /// Previous node in the optimal path.
  final _Node? prev;
}

/// Solves the Knuth-Plass optimal line-breaking problem.
///
/// Ported from tex-linebreak (robertknight/tex-linebreak) `layout.ts`.
///
/// Given a list of [KPItem]s and a target line width, finds the set of
/// break points that minimises total demerits.
///
/// Returns a list of breakpoint indices into [items]. The first element is
/// always 0 (start of paragraph), the last is the index of the forced break
/// at the end.
///
/// Never returns `null` — uses emergency breaks when no feasible solution
/// exists. Throws [MaxAdjustmentExceededError] when `maxAdjustmentRatio` is
/// set and exceeded (caller should retry with hyphenation).
class KPSolver {
  const KPSolver._();

  /// Break [items] into lines of width [lineWidth].
  ///
  /// Returns indices into [items] marking where each line ends.
  static List<int> solve(
    List<KPItem> items,
    double lineWidth, [
    KPOptions options = const KPOptions(),
  ]) {
    if (items.isEmpty) return [];

    var hasNegativeValues = false;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it is KPBox) {
        if (it.width < 0) { hasNegativeValues = true; break; }
      } else if (it is KPGlue) {
        if (it.width < 0 || it.stretch < 0 || it.shrink < 0) {
          hasNegativeValues = true;
          break;
        }
      } else if (it is KPPenalty) {
        if (it.width < 0) { hasNegativeValues = true; break; }
      }
    }

    final currentMaxAdjustmentRatio = math.min(
      options.initialMaxAdjustmentRatio,
      options.maxAdjustmentRatio ?? double.infinity,
    );

    // Active node list (List is faster than Set for small collections of
    // 5-15 nodes — avoids iterator/hashCode overhead).
    final active = <_Node>[
      _Node(
        index: 0,
        line: 0,
        fitness: 0,
        totalWidth: 0.0,
        totalStretch: 0.0,
        totalShrink: 0.0,
        totalDemerits: 0.0,
      ),
    ];

    // Running sums.
    var sumWidth = 0.0;
    var sumStretch = 0.0;
    var sumShrink = 0.0;

    var minAdjustmentRatioAboveThreshold = double.infinity;

    for (var b = 0; b < items.length; b++) {
      final item = items[b];

      // Determine if this is a feasible breakpoint and update sums.
      // Matches tex-linebreak lines 210-225.
      var canBreak = false;
      if (item is KPBox) {
        sumWidth += item.width;
      } else if (item is KPGlue) {
        canBreak = b > 0 && items[b - 1] is KPBox;
        if (!canBreak) {
          // Non-breakable glue: accumulate immediately.
          sumWidth += item.width;
          sumShrink += item.shrink;
          sumStretch += item.stretch;
        }
      } else if (item is KPPenalty) {
        canBreak = item.cost < KPPenalty.maxCost;
      }
      if (!canBreak) continue;

      // Pre-compute look-ahead to next box ONCE per breakpoint b.
      // This only depends on items[b..], not on the active node, so it can
      // be hoisted out of the active-node loop. (tex-linebreak lines 354-370)
      var widthToNextBox = 0.0;
      var shrinkToNextBox = 0.0;
      var stretchToNextBox = 0.0;
      for (var bp = b; bp < items.length; bp++) {
        final it = items[bp];
        if (it is KPBox) break;
        if (it is KPPenalty && it.cost >= KPPenalty.maxCost) break;
        widthToNextBox += it is KPGlue
            ? it.width
            : it is KPPenalty
                ? it.width
                : 0.0;
        if (it is KPGlue) {
          shrinkToNextBox += it.shrink;
          stretchToNextBox += it.stretch;
        }
      }

      // Update the active node list.
      _Node? lastActive;
      _Node? bestFeasible;
      final forcedBreak = _isForcedBreak(item);

      for (var ai = active.length - 1; ai >= 0; ai--) {
        final a = active[ai];

        // Compute adjustment ratio from `a` to `b`.
        final lineShrink = sumShrink - a.totalShrink;
        final lineStretch = sumStretch - a.totalStretch;
        var actualLen = sumWidth - a.totalWidth;

        // Include penalty width if chosen as a breakpoint.
        if (item is KPPenalty) {
          actualLen += item.width;
        }

        // Division by zero produces Infinity in Dart (for doubles),
        // which is what we want.
        double adjustmentRatio;
        if (actualLen < lineWidth) {
          adjustmentRatio = (lineWidth - actualLen) / lineStretch;
        } else {
          adjustmentRatio = (lineWidth - actualLen) / lineShrink;
        }

        if (adjustmentRatio > currentMaxAdjustmentRatio) {
          minAdjustmentRatioAboveThreshold = math.min(
            adjustmentRatio,
            minAdjustmentRatioAboveThreshold,
          );
        }

        // TeX's `r < -1` pruning is only safe when all widths/stretch/shrink
        // are non-negative (Restriction 1). Forced breaks always prune.
        if ((!hasNegativeValues && adjustmentRatio < _minAdjustmentRatio) ||
            forcedBreak) {
          lastActive = a;
          active.removeAt(ai);
        }

        if (adjustmentRatio >= _minAdjustmentRatio &&
            adjustmentRatio <= currentMaxAdjustmentRatio) {
          // Feasible line. Compute demerits as per formula on p. 1128.
          final badness = 100.0 * math.pow(adjustmentRatio.abs(), 3);
          final penalty = item is KPPenalty ? item.cost : 0.0;

          double demerits;
          if (penalty >= 0) {
            demerits = math.pow(1 + badness + penalty, 2).toDouble();
          } else if (penalty > KPPenalty.minCost) {
            demerits =
                math.pow(1 + badness, 2).toDouble() -
                math.pow(penalty, 2).toDouble();
          } else {
            demerits = math.pow(1 + badness, 2).toDouble();
          }

          // Consecutive flagged breaks penalty.
          final prevItem = items[a.index];
          if (item is KPPenalty &&
              prevItem is KPPenalty &&
              item.flagged &&
              prevItem.flagged) {
            demerits += options.doubleHyphenPenalty;
          }

          // Fitness classes (p. 1155).
          int fitness;
          if (adjustmentRatio < -0.5) {
            fitness = 0;
          } else if (adjustmentRatio < 0.5) {
            fitness = 1;
          } else if (adjustmentRatio < 1.0) {
            fitness = 2;
          } else {
            fitness = 3;
          }
          if (a.index > 0 && (fitness - a.fitness).abs() > 1) {
            demerits += options.adjacentLooseTightPenalty;
          }

          // Use pre-computed look-ahead values (hoisted above active loop).
          final totalDemerits = a.totalDemerits + demerits;
          if (bestFeasible == null ||
              totalDemerits < bestFeasible.totalDemerits) {
            bestFeasible = _Node(
              index: b,
              line: a.line + 1,
              fitness: fitness,
              totalWidth: sumWidth + widthToNextBox,
              totalShrink: sumShrink + shrinkToNextBox,
              totalStretch: sumStretch + stretchToNextBox,
              totalDemerits: totalDemerits,
              prev: a,
            );
          }
        }
      }

      // Add the single best feasible node (lowest totalDemerits).
      if (bestFeasible != null) {
        active.add(bestFeasible);
      }

      // Handle empty active set.
      if (active.isEmpty) {
        if (minAdjustmentRatioAboveThreshold.isFinite) {
          if (options.maxAdjustmentRatio == currentMaxAdjustmentRatio) {
            throw const MaxAdjustmentExceededError();
          }
          // Retry with higher threshold.
          return solve(
            items,
            lineWidth,
            KPOptions(
              maxAdjustmentRatio: options.maxAdjustmentRatio,
              initialMaxAdjustmentRatio: minAdjustmentRatioAboveThreshold * 2,
              doubleHyphenPenalty: options.doubleHyphenPenalty,
              adjacentLooseTightPenalty: options.adjacentLooseTightPenalty,
            ),
          );
        } else {
          // Emergency break: force a break at the current position.
          active.add(
            _Node(
              index: b,
              line: lastActive!.line + 1,
              fitness: 1,
              totalWidth: sumWidth,
              totalShrink: sumShrink,
              totalStretch: sumStretch,
              totalDemerits: lastActive.totalDemerits + 1000,
              prev: lastActive,
            ),
          );
        }
      }

      // Accumulate breakable glue *after* break processing.
      if (item is KPGlue) {
        sumWidth += item.width;
        sumStretch += item.stretch;
        sumShrink += item.shrink;
      }
    }

    // Choose active node with fewest total demerits.
    _Node? bestNode;
    for (final a in active) {
      if (bestNode == null || a.totalDemerits < bestNode.totalDemerits) {
        bestNode = a;
      }
    }

    // Backtrack to collect breakpoints.
    final output = <int>[];
    _Node? next = bestNode;
    while (next != null) {
      output.add(next.index);
      next = next.prev;
    }
    return output.reversed.toList();
  }

  /// Compute per-line adjustment ratios given items and breakpoints.
  ///
  /// Ported from tex-linebreak `adjustmentRatios()` (layout.ts lines 492-531).
  ///
  /// Returns a list of ratios, one per line. Positive means glue must stretch,
  /// negative means glue must shrink, zero means perfect fit.
  static List<double> adjustmentRatios(
    List<KPItem> items,
    double lineWidth,
    List<int> breakpoints,
  ) {
    final ratios = <double>[];

    for (var b = 0; b < breakpoints.length - 1; b++) {
      var actualWidth = 0.0;
      var lineShrink = 0.0;
      var lineStretch = 0.0;

      final start = b == 0 ? breakpoints[b] : breakpoints[b] + 1;
      final end = breakpoints[b + 1];

      for (var p = start; p <= end; p++) {
        final item = items[p];
        if (item is KPBox) {
          actualWidth += item.width;
        } else if (item is KPGlue && p != start && p != end) {
          actualWidth += item.width;
          lineShrink += item.shrink;
          lineStretch += item.stretch;
        } else if (item is KPPenalty && p == end) {
          actualWidth += item.width;
        }
      }

      double ratio;
      if (actualWidth < lineWidth) {
        ratio = (lineWidth - actualWidth) / lineStretch;
      } else {
        ratio = (lineWidth - actualWidth) / lineShrink;
      }
      ratios.add(ratio);
    }

    return ratios;
  }

  /// Compute positioned items for a chosen breakpoint sequence.
  ///
  /// Mirrors tex-linebreak `positionItems()`.
  static List<KPPositionedItem> positionItems(
    List<KPItem> items,
    double lineWidth,
    List<int> breakpoints, {
    bool includeGlue = false,
  }) {
    final adjRatios = adjustmentRatios(items, lineWidth, breakpoints);
    final output = <KPPositionedItem>[];

    for (var b = 0; b < breakpoints.length - 1; b++) {
      final isLastLine = b == breakpoints.length - 2;
      // Cap stretch ratio for non-last lines to prevent excessively wide
      // word spacing when a line has few words (e.g. after a page split).
      final maxRatio = isLastLine ? double.infinity : _maxVisualRatio;
      final adjustmentRatio =
          adjRatios[b].clamp(_minAdjustmentRatio, maxRatio);
      var xOffset = 0.0;
      final start = b == 0 ? breakpoints[b] : breakpoints[b] + 1;
      final end = breakpoints[b + 1];

      for (var p = start; p <= end; p++) {
        final item = items[p];
        if (item is KPBox) {
          output.add(
            KPPositionedItem(
              item: p,
              line: b,
              xOffset: xOffset,
              width: item.width,
            ),
          );
          xOffset += item.width;
        } else if (item is KPGlue && p != start && p != end) {
          final gap = adjustmentRatio < 0
              ? item.width + adjustmentRatio * item.shrink
              : item.width + adjustmentRatio * item.stretch;
          if (includeGlue) {
            output.add(
              KPPositionedItem(item: p, line: b, xOffset: xOffset, width: gap),
            );
          }
          xOffset += gap;
        } else if (item is KPPenalty && p == end && item.width > 0) {
          output.add(
            KPPositionedItem(
              item: p,
              line: b,
              xOffset: xOffset,
              width: item.width,
            ),
          );
        }
      }
    }

    return output;
  }
}
