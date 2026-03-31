import 'dart:math' show max, min;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models/page_layout.dart';

/// A position within a [PageLayout]: element index + character offset.
class PagePosition implements Comparable<PagePosition> {
  const PagePosition({required this.elementIndex, required this.charOffset});

  final int elementIndex;
  final int charOffset;

  @override
  int compareTo(PagePosition other) {
    final cmp = elementIndex.compareTo(other.elementIndex);
    if (cmp != 0) return cmp;
    return charOffset.compareTo(other.charOffset);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PagePosition &&
          elementIndex == other.elementIndex &&
          charOffset == other.charOffset;

  @override
  int get hashCode => Object.hash(elementIndex, charOffset);
}

/// A text selection range within a single page.
class PageSelection {
  const PageSelection({required this.start, required this.end});

  /// The earlier position (smaller element index / char offset).
  final PagePosition start;

  /// The later position.
  final PagePosition end;

  /// Create a normalized selection (start <= end) from two arbitrary positions.
  factory PageSelection.normalized(PagePosition a, PagePosition b) {
    if (a.compareTo(b) <= 0) {
      return PageSelection(start: a, end: b);
    }
    return PageSelection(start: b, end: a);
  }
}

/// Hit-test a content-area offset against text elements on a page.
///
/// Returns the [PagePosition] for the closest text element, or null if the
/// page has no text elements.
PagePosition? hitTestPage(PageLayout page, Offset contentOffset) {
  // First pass: exact hit on an element rect.
  for (var i = 0; i < page.elements.length; i++) {
    final el = page.elements[i];
    final painter = el.ensurePainter();
    if (painter == null) continue;
    if (el.rect.contains(contentOffset)) {
      final local = contentOffset - el.rect.topLeft;
      final pos = painter.getPositionForOffset(local);
      return PagePosition(elementIndex: i, charOffset: pos.offset);
    }
  }

  // Second pass: find nearest text element by vertical then horizontal distance.
  return _findNearest(page, contentOffset);
}

PagePosition? _findNearest(PageLayout page, Offset offset) {
  int? bestIndex;
  double bestDist = double.infinity;

  for (var i = 0; i < page.elements.length; i++) {
    final el = page.elements[i];
    final painter = el.ensurePainter();
    if (painter == null) continue;

    // Distance from offset to the closest point on the rect.
    final clampedX = offset.dx.clamp(el.rect.left, el.rect.right);
    final clampedY = offset.dy.clamp(el.rect.top, el.rect.bottom);
    final dx = offset.dx - clampedX;
    final dy = offset.dy - clampedY;
    final dist = dx * dx + dy * dy;

    if (dist < bestDist) {
      bestDist = dist;
      bestIndex = i;
    }
  }

  if (bestIndex == null) return null;

  final el = page.elements[bestIndex];
  final local = Offset(
    (offset.dx - el.rect.left).clamp(0, el.rect.width),
    (offset.dy - el.rect.top).clamp(0, el.rect.height),
  );
  final painter = el.ensurePainter();
  if (painter == null) return null;
  final pos = painter.getPositionForOffset(local);
  return PagePosition(elementIndex: bestIndex, charOffset: pos.offset);
}

/// Expand a [PagePosition] to word boundaries within its element.
///
/// Returns a selection covering the full word. For K-P fragments (single-word
/// elements), selects the entire element text.
PageSelection? expandToWord(PageLayout page, PagePosition position) {
  final el = page.elements[position.elementIndex];
  final painter = el.ensurePainter();
  if (painter == null) return null;

  final text = _extractPainterText(painter);
  if (text.isEmpty) return null;

  final offset = position.charOffset.clamp(0, text.length);

  // Find word boundaries.
  var start = offset;
  var end = offset;

  while (start > 0 && _isWordChar(text[start - 1])) {
    start--;
  }
  while (end < text.length && _isWordChar(text[end])) {
    end++;
  }

  // If we didn't expand (hit whitespace/punctuation), select the single char.
  if (start == end && text.isNotEmpty) {
    start = offset.clamp(0, text.length - 1);
    end = start + 1;
  }

  return PageSelection(
    start: PagePosition(elementIndex: position.elementIndex, charOffset: start),
    end: PagePosition(elementIndex: position.elementIndex, charOffset: end),
  );
}

/// Snap a hit position to the nearest word boundary.
///
/// [isForward] indicates whether the moving end is after the anchor in book
/// order. When true, snaps to the END of the word at [movingPos]; when false,
/// snaps to the START. The caller must determine direction using full
/// [BookPosition] comparison so that cross-page selections are handled
/// correctly.
PagePosition snapToWordBoundary(
  PageLayout page,
  PagePosition movingPos, {
  required bool isForward,
}) {
  final el = page.elements[movingPos.elementIndex];
  final painter = el.ensurePainter();
  if (painter == null) return movingPos;

  final text = _extractPainterText(painter);
  if (text.isEmpty) return movingPos;

  final offset = movingPos.charOffset.clamp(0, text.length);

  if (isForward) {
    // Snap to end of word.
    var end = offset;
    while (end < text.length && _isWordChar(text[end])) {
      end++;
    }
    return PagePosition(elementIndex: movingPos.elementIndex, charOffset: end);
  } else {
    // Snap to start of word.
    var start = offset;
    while (start > 0 && _isWordChar(text[start - 1])) {
      start--;
    }
    return PagePosition(
      elementIndex: movingPos.elementIndex,
      charOffset: start,
    );
  }
}

bool _isWordChar(String ch) {
  // Letters, digits, CJK characters.
  final code = ch.codeUnitAt(0);
  if (code >= 0x4E00 && code <= 0x9FFF) return true; // CJK Unified
  if (code >= 0x3400 && code <= 0x4DBF) return true; // CJK Extension A
  if (code >= 0x3000 && code <= 0x303F) return false; // CJK punctuation
  if (code >= 0xFF00 && code <= 0xFF60) return false; // Fullwidth punctuation
  final r = RegExp(r'[\w]');
  return r.hasMatch(ch);
}

/// Compute highlight rectangles for a selection, in content-area coordinates.
List<Rect> getSelectionRects(PageLayout page, PageSelection selection) {
  final rects = <Rect>[];

  final startIdx = selection.start.elementIndex;
  final endIdx = selection.end.elementIndex;

  for (var i = startIdx; i <= endIdx; i++) {
    if (i < 0 || i >= page.elements.length) continue;
    final el = page.elements[i];
    final painter = el.ensurePainter();
    if (painter == null) continue;

    final text = _extractPainterText(painter);
    if (text.isEmpty) continue;

    // Determine char range within this element.
    int selStart;
    int selEnd;

    if (i == startIdx && i == endIdx) {
      selStart = selection.start.charOffset;
      selEnd = selection.end.charOffset;
    } else if (i == startIdx) {
      selStart = selection.start.charOffset;
      selEnd = text.length;
    } else if (i == endIdx) {
      selStart = 0;
      selEnd = selection.end.charOffset;
    } else {
      selStart = 0;
      selEnd = text.length;
    }

    selStart = selStart.clamp(0, text.length);
    selEnd = selEnd.clamp(0, text.length);
    if (selStart >= selEnd) {
      // For full-element selection (e.g. K-P fragment fully covered)
      if (i > startIdx && i < endIdx) {
        rects.add(el.rect);
      }
      continue;
    }

    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: selStart, extentOffset: selEnd),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );

    for (final box in boxes) {
      rects.add(
        Rect.fromLTRB(
          el.rect.left + box.left,
          el.rect.top + box.top,
          el.rect.left + box.right,
          el.rect.top + box.bottom,
        ),
      );
    }

    // Fallback if getBoxesForSelection returns nothing (K-P single-word).
    if (boxes.isEmpty && selStart == 0 && selEnd == text.length) {
      rects.add(el.rect);
    }
  }

  return _mergeSelectionRects(rects);
}

/// Merge adjacent rects on the same line into continuous highlight bands.
///
/// K-P justified fragments produce per-word rects with gaps between them.
/// This merges rects whose vertical ranges overlap into single line-spanning
/// rectangles so the highlight appears continuous.
List<Rect> _mergeSelectionRects(List<Rect> rects) {
  if (rects.length <= 1) return rects;

  final sorted = List<Rect>.from(rects)
    ..sort((a, b) {
      final dy = a.top.compareTo(b.top);
      return dy != 0 ? dy : a.left.compareTo(b.left);
    });

  final merged = <Rect>[];
  var current = sorted.first;

  for (var i = 1; i < sorted.length; i++) {
    final next = sorted[i];
    // Same line if vertical overlap > 50% of the shorter rect height.
    final overlapTop = max(current.top, next.top);
    final overlapBot = min(current.bottom, next.bottom);
    final minHeight = min(current.height, next.height);
    if (overlapBot - overlapTop > minHeight * 0.5) {
      current = Rect.fromLTRB(
        min(current.left, next.left),
        min(current.top, next.top),
        max(current.right, next.right),
        max(current.bottom, next.bottom),
      );
    } else {
      merged.add(current);
      current = next;
    }
  }
  merged.add(current);
  return merged;
}

/// The length of the plain text in a [TextPainter]'s span tree.
int extractPainterTextLength(TextPainter painter) =>
    _extractPainterText(painter).length;

/// Extract the plain text from a TextPainter's TextSpan tree.
String _extractPainterText(TextPainter painter) {
  final span = painter.text;
  if (span == null) return '';
  final buffer = StringBuffer();
  _visitSpan(span, buffer);
  return buffer.toString();
}

void _visitSpan(InlineSpan span, StringBuffer buffer) {
  if (span is TextSpan) {
    if (span.text != null) buffer.write(span.text);
    if (span.children != null) {
      for (final child in span.children!) {
        _visitSpan(child, buffer);
      }
    }
  }
}

/// Extract the selected text as a string.
String extractSelectedText(PageLayout page, PageSelection selection) {
  final buffer = StringBuffer();

  final startIdx = selection.start.elementIndex;
  final endIdx = selection.end.elementIndex;

  for (var i = startIdx; i <= endIdx; i++) {
    if (i < 0 || i >= page.elements.length) continue;
    final el = page.elements[i];
    final painter = el.ensurePainter();
    if (painter == null) continue;

    final text = _extractPainterText(painter);
    if (text.isEmpty) continue;

    int selStart;
    int selEnd;

    if (i == startIdx && i == endIdx) {
      selStart = selection.start.charOffset;
      selEnd = selection.end.charOffset;
    } else if (i == startIdx) {
      selStart = selection.start.charOffset;
      selEnd = text.length;
    } else if (i == endIdx) {
      selStart = 0;
      selEnd = selection.end.charOffset;
    } else {
      selStart = 0;
      selEnd = text.length;
    }

    selStart = selStart.clamp(0, text.length);
    selEnd = selEnd.clamp(0, text.length);
    if (selStart < selEnd) {
      buffer.write(text.substring(selStart, selEnd));
    }
  }

  return buffer.toString();
}

/// Extract the full plain text of a page by concatenating all text elements.
String extractFullPageText(PageLayout page) {
  final buffer = StringBuffer();
  for (final el in page.elements) {
    final painter = el.ensurePainter();
    if (painter == null) continue;
    final text = _extractPainterText(painter);
    if (text.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(text);
    }
  }
  return buffer.toString();
}
