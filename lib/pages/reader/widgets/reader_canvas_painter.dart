import 'package:flutter/rendering.dart';

import '../../../entities/annotation-entity.dart';
import '../../../services/reader/models/page_layout.dart';
import '../../../services/reader/models/reader_preferences.dart';
import '../../../services/reader/models/render_node.dart';

class AnnotationPaintBucket {
  const AnnotationPaintBucket({
    required this.style,
    required this.color,
    required this.rects,
  });

  final AnnotationStyle style;
  final Color color;
  final List<Rect> rects;
}

/// Paints a single [PageLayout] onto a Canvas.
///
/// Each [LayoutElement] is drawn at its absolute position within the page
/// content area.  The canvas is translated by the page padding before
/// painting so that element rects are relative to the top-left of the
/// content area.
class ReaderCanvasPainter extends CustomPainter {
  ReaderCanvasPainter({
    required this.page,
    required this.preferences,
    this.safeAreaTop = 0.0,
    this.safeAreaBottom = 0.0,
    this.annotationPaintBuckets,
    this.selectionRects,
  });

  final PageLayout page;
  final ReaderPreferences preferences;
  final double safeAreaTop;
  final double safeAreaBottom;
  final List<AnnotationPaintBucket>? annotationPaintBuckets;

  /// Selection highlight rectangles in content-area coordinates.
  final List<Rect>? selectionRects;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = preferences.theme.backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    canvas.save();
    canvas.translate(
      preferences.pageHorizontalPaddingPx,
      preferences.pageVerticalPaddingPx + safeAreaTop,
    );

    _paintHighlightBuckets(canvas);

    if (selectionRects != null && selectionRects!.isNotEmpty) {
      final selPaint = Paint()..color = const Color(0x4D3B82F6);
      for (final rect in selectionRects!) {
        canvas.drawRect(rect, selPaint);
      }
    }

    for (final element in page.elements) {
      _paintElement(canvas, element);
    }

    _paintUnderlineBuckets(canvas);
    canvas.restore();
  }

  void _paintHighlightBuckets(Canvas canvas) {
    final buckets = annotationPaintBuckets;
    if (buckets == null || buckets.isEmpty) {
      return;
    }
    for (final bucket in buckets) {
      if (bucket.style != AnnotationStyle.highlight) {
        continue;
      }
      final annotationPaint = Paint()..color = bucket.color;
      for (final rect in bucket.rects) {
        canvas.drawRect(rect, annotationPaint);
      }
    }
  }

  void _paintUnderlineBuckets(Canvas canvas) {
    final buckets = annotationPaintBuckets;
    if (buckets == null || buckets.isEmpty) {
      return;
    }
    for (final bucket in buckets) {
      if (bucket.style != AnnotationStyle.underline) {
        continue;
      }
      final underlinePaint = Paint()
        ..color = bucket.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (final rect in bucket.rects) {
        final y = rect.bottom - 1.5;
        canvas.drawLine(
          Offset(rect.left, y),
          Offset(rect.right, y),
          underlinePaint,
        );
      }
    }
  }

  void _paintElement(Canvas canvas, LayoutElement element) {
    if (element.backgroundPaint != null) {
      canvas.drawRect(element.rect, element.backgroundPaint!);
    }

    final tp = element.ensurePainter();
    if (tp != null) {
      tp.paint(canvas, element.rect.topLeft);
    }

    if (element.image != null) {
      paintImage(
        canvas: canvas,
        rect: element.rect,
        image: element.image!,
        fit: BoxFit.contain,
      );
    }

    if (element.sourceNode is HorizontalRuleNode &&
        !element.hasText &&
        element.image == null &&
        element.backgroundPaint == null) {
      final rulePaint = Paint()
        ..color = preferences.theme.textColor.withValues(alpha: 0.3)
        ..strokeWidth = 1.0;
      final y = element.rect.center.dy;
      canvas.drawLine(
        Offset(element.rect.left, y),
        Offset(element.rect.right, y),
        rulePaint,
      );
    }
  }

  @override
  bool shouldRepaint(ReaderCanvasPainter oldDelegate) {
    return oldDelegate.page != page ||
        oldDelegate.preferences != preferences ||
        oldDelegate.safeAreaTop != safeAreaTop ||
        oldDelegate.safeAreaBottom != safeAreaBottom ||
        oldDelegate.annotationPaintBuckets != annotationPaintBuckets ||
        oldDelegate.selectionRects != selectionRects;
  }
}
