import 'package:flutter/rendering.dart';

import '../../../services/reader/models/page_layout.dart';
import '../../../services/reader/models/reader_preferences.dart';
import '../../../services/reader/models/render_node.dart';

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
  });

  final PageLayout page;
  final ReaderPreferences preferences;
  final double safeAreaTop;
  final double safeAreaBottom;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fill page background.
    final bgPaint = Paint()..color = preferences.theme.backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Translate to the content area origin (inside page padding + safe area).
    canvas.save();
    canvas.translate(
      preferences.pageHorizontalPaddingPx,
      preferences.pageVerticalPaddingPx + safeAreaTop,
    );

    // 3. Paint each element.
    for (final element in page.elements) {
      _paintElement(canvas, element);
    }

    canvas.restore();
  }

  void _paintElement(Canvas canvas, LayoutElement element) {
    // Background fill (paragraph bg, table cell bg, code block bg).
    if (element.backgroundPaint != null) {
      canvas.drawRect(element.rect, element.backgroundPaint!);
    }

    // Text content.
    if (element.textPainter != null) {
      element.textPainter!.paint(canvas, element.rect.topLeft);
    }

    // Image content.
    if (element.image != null) {
      paintImage(
        canvas: canvas,
        rect: element.rect,
        image: element.image!,
        fit: BoxFit.contain,
      );
    }

    // Horizontal rule: draw a thin line across the element rect.
    if (element.sourceNode is HorizontalRuleNode &&
        element.textPainter == null &&
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
        oldDelegate.safeAreaBottom != safeAreaBottom;
  }
}
