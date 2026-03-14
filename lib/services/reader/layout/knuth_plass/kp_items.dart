import 'package:flutter/painting.dart';

/// Knuth-Plass item types for the line-breaking algorithm.
///
/// Text is modelled as a sequence of boxes (words), glue (stretchable spaces),
/// and penalties (possible/forced break points).
///
/// Follows the model from tex-linebreak (robertknight/tex-linebreak).

sealed class KPItem {
  const KPItem();
}

/// A fixed-width, non-breakable piece of content (typically a word).
class KPBox extends KPItem {
  KPBox({
    required this.width,
    required this.text,
    required this.style,
    this.painter,
  });

  final double width;
  final String text;
  final TextStyle? style;

  /// Pre-measured [TextPainter] for this box, reused at render time to
  /// eliminate measurement drift between item building and rendering.
  final TextPainter? painter;
}

/// A stretchable/shrinkable space between boxes.
class KPGlue extends KPItem {
  const KPGlue({
    required this.width,
    required this.stretch,
    required this.shrink,
  });

  /// Preferred width of this space (natural space width).
  final double width;

  /// Maximum amount by which this space can grow.
  final double stretch;

  /// Maximum amount by which this space can shrink.
  final double shrink;
}

/// An explicit candidate position for breaking a line.
class KPPenalty extends KPItem {
  const KPPenalty({
    required this.cost,
    this.width = 0.0,
    this.flagged = false,
  });

  /// The undesirability of breaking the line at this point.
  /// Values <= [minCost] force a break.
  /// Values >= [maxCost] prevent a break.
  final double cost;

  /// Extra width added if a break occurs here (e.g. a hyphen character).
  final double width;

  /// Hint to avoid successive lines broken at flagged penalties (e.g. hyphens).
  final bool flagged;

  /// Minimum cost. Values at or below this force a break.
  static const double minCost = -1000;

  /// Maximum cost. Values at or above this prevent a break.
  static const double maxCost = 1000;
}

/// Create a forced line-break penalty.
KPPenalty forcedBreak() =>
    const KPPenalty(cost: KPPenalty.minCost);
