import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../entities/chapter-entity.dart';
import '../../entities/reader-pagination-cache-entity.dart';
import '../../shared/constants/reader-constants.dart';
import 'reader-page-slice.dart';

/// Immutable result of a single-character font measurement.
/// Computed once per layout change; all subsequent page splits use math only.
class ReaderFontMetrics {
  const ReaderFontMetrics({
    required this.charWidth,
    required this.lineHeight,
    required this.charsPerLine,
    required this.linesPerPage,
  });

  final double charWidth;
  final double lineHeight;
  final int charsPerLine;
  final int linesPerPage;
}

class ReaderPaginationEngine {
  /// Measure font metrics with a single TextPainter call on a representative
  /// CJK character. For Chinese novels (monospace CJK), this is sufficient to
  /// compute exact page boundaries for the entire book via integer arithmetic.
  static ReaderFontMetrics measureFontMetrics({
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: '中', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final charWidth = painter.width;
    final lineHeight = painter.height;
    return ReaderFontMetrics(
      charWidth: charWidth,
      lineHeight: lineHeight,
      charsPerLine: math.max(1, (maxWidth / math.max(1.0, charWidth)).floor()),
      linesPerPage: math.max(
        1,
        (maxHeight / math.max(1.0, lineHeight)).floor(),
      ),
    );
  }

  /// Build pages using pure integer line-scanning: O(total chars), no
  /// TextPainter calls. Newlines (\n) are treated as line-ending characters.
  List<ReaderPageSlice> buildPagesMath({
    required List<ChapterEntity> chapters,
    required ReaderFontMetrics metrics,
    required int chapterStart,
    required int chapterEnd,
  }) {
    final pages = <ReaderPageSlice>[];
    var globalOffset = 0;
    for (var i = 0; i < chapterStart; i++) {
      globalOffset += chapters[i].content.length;
    }
    for (
      var chapterIndex = chapterStart;
      chapterIndex <= chapterEnd;
      chapterIndex++
    ) {
      final chapter = chapters[chapterIndex];
      var start = 0;
      final content = chapter.content;
      while (start < content.length) {
        final end = _scanPageEnd(
          text: content,
          startOffset: start,
          charsPerLine: metrics.charsPerLine,
          linesPerPage: metrics.linesPerPage,
        );
        final safeEnd = end <= start
            ? math.min(content.length, start + metrics.charsPerLine)
            : end;
        pages.add(
          ReaderPageSlice(
            chapterIndex: chapterIndex,
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            startOffset: start,
            endOffset: safeEnd,
            globalStartOffset: globalOffset + start,
            globalEndOffset: globalOffset + safeEnd,
            text: content.substring(start, safeEnd),
          ),
        );
        start = safeEnd;
      }
      globalOffset += content.length;
    }
    return pages;
  }

  /// Scan character by character to find the exclusive end offset of a page.
  /// '\n' ends the current line; character wrap occurs at [charsPerLine].
  int scanPageEnd({
    required String text,
    required int startOffset,
    required int charsPerLine,
    required int linesPerPage,
  }) {
    return _scanPageEnd(
      text: text,
      startOffset: startOffset,
      charsPerLine: charsPerLine,
      linesPerPage: linesPerPage,
    );
  }

  int _scanPageEnd({
    required String text,
    required int startOffset,
    required int charsPerLine,
    required int linesPerPage,
  }) {
    var lines = 0;
    var charsOnLine = 0;
    for (var i = startOffset; i < text.length; i++) {
      if (text[i] == '\n') {
        lines++;
        charsOnLine = 0;
      } else {
        charsOnLine++;
        if (charsOnLine == charsPerLine) {
          lines++;
          charsOnLine = 0;
        }
      }
      if (lines == linesPerPage) {
        return i + 1;
      }
    }
    return text.length;
  }

  List<ReaderPageSlice> buildPages({
    required List<ChapterEntity> chapters,
    required TextStyle textStyle,
    required double horizontalPadding,
    required double verticalPadding,
    required Size viewport,
    required bool approximate,
    required int chapterStart,
    required int chapterEnd,
  }) {
    final pages = <ReaderPageSlice>[];
    var globalOffset = 0;
    for (var i = 0; i < chapterStart; i++) {
      globalOffset += chapters[i].content.length;
    }
    final maxWidth = math
        .max(120.0, viewport.width - horizontalPadding * 2)
        .toDouble();
    final maxHeight = math
        .max(160.0, viewport.height - verticalPadding * 2)
        .toDouble();

    for (
      var chapterIndex = chapterStart;
      chapterIndex <= chapterEnd;
      chapterIndex++
    ) {
      final chapter = chapters[chapterIndex];
      var start = 0;
      final content = chapter.content;
      while (start < content.length) {
        final end = approximate
            ? _fitApproximateEndOffset(
                text: content,
                startOffset: start,
                fontSize: textStyle.fontSize ?? 19,
              )
            : _fitTextEndOffset(
                text: content,
                startOffset: start,
                maxWidth: maxWidth,
                maxHeight: maxHeight,
                style: textStyle,
              );
        final safeEnd = end <= start
            ? math.min(content.length, start + 220)
            : end;
        pages.add(
          ReaderPageSlice(
            chapterIndex: chapterIndex,
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            startOffset: start,
            endOffset: safeEnd,
            globalStartOffset: globalOffset + start,
            globalEndOffset: globalOffset + safeEnd,
            text: content.substring(start, safeEnd),
          ),
        );
        start = safeEnd;
      }
      globalOffset += content.length;
    }
    return pages;
  }

  List<ReaderPageSlice> pagesFromCachedSlices({
    required List<ChapterEntity> chapters,
    required List<ReaderPaginationSliceEntity> slices,
  }) {
    var globalOffset = 0;
    final chapterGlobalStart = <int, int>{};
    for (var i = 0; i < chapters.length; i++) {
      chapterGlobalStart[i] = globalOffset;
      globalOffset += chapters[i].content.length;
    }
    return slices
        .where(
          (slice) =>
              slice.chapterIndex >= 0 && slice.chapterIndex < chapters.length,
        )
        .map((slice) {
          final chapter = chapters[slice.chapterIndex];
          final globalStart =
              (chapterGlobalStart[slice.chapterIndex] ?? 0) + slice.startOffset;
          final globalEnd =
              (chapterGlobalStart[slice.chapterIndex] ?? 0) + slice.endOffset;
          final safeStart = slice.startOffset.clamp(0, chapter.content.length);
          final safeEnd = slice.endOffset.clamp(
            safeStart,
            chapter.content.length,
          );
          return ReaderPageSlice(
            chapterIndex: slice.chapterIndex,
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            startOffset: safeStart,
            endOffset: safeEnd,
            globalStartOffset: globalStart,
            globalEndOffset: globalEnd,
            text: chapter.content.substring(safeStart, safeEnd),
          );
        })
        .toList(growable: false);
  }

  int fitTextEndOffset({
    required String text,
    required int startOffset,
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
  }) {
    var low = startOffset + 1;
    var high = text.length;
    var best = startOffset + 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final candidate = text.substring(startOffset, mid);
      final painter = TextPainter(
        text: TextSpan(text: candidate, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      if (painter.height <= maxHeight) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return best;
  }

  int _fitTextEndOffset({
    required String text,
    required int startOffset,
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
  }) {
    return fitTextEndOffset(
      text: text,
      startOffset: startOffset,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      style: style,
    );
  }

  int fitApproximateEndOffset({
    required String text,
    required int startOffset,
    required double fontSize,
  }) {
    final scale = (19 / fontSize).clamp(0.7, 1.4);
    final perPage = (ReaderConstants.estimatedCharsPerPage * scale).round();
    return math.min(text.length, startOffset + math.max(260, perPage));
  }

  int _fitApproximateEndOffset({
    required String text,
    required int startOffset,
    required double fontSize,
  }) {
    return fitApproximateEndOffset(
      text: text,
      startOffset: startOffset,
      fontSize: fontSize,
    );
  }
}
