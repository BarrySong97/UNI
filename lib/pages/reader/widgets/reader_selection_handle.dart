import 'package:flutter/material.dart';

/// A draggable text selection handle (teardrop shape).
class ReaderSelectionHandle extends StatelessWidget {
  const ReaderSelectionHandle({
    super.key,
    required this.color,
    required this.onDragUpdate,
    this.onDragEnd,
    this.isStart = true,
  });

  /// The handle accent color.
  final Color color;

  /// Whether this is the start (left) or end (right) handle.
  final bool isStart;

  /// Called with delta offset during drag.
  final void Function(DragUpdateDetails details) onDragUpdate;

  /// Called when the drag gesture ends.
  final void Function(DragEndDetails details)? onDragEnd;

  static const double handleRadius = 8.0;
  static const double lineHeight = 20.0;
  static const double hitSize = 40.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onDragUpdate,
      onPanEnd: onDragEnd,
      child: SizedBox(
        width: hitSize,
        height: hitSize,
        child: CustomPaint(
          painter: _HandlePainter(color: color, isStart: isStart),
        ),
      ),
    );
  }
}

class _HandlePainter extends CustomPainter {
  _HandlePainter({required this.color, required this.isStart});

  final Color color;
  final bool isStart;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;

    // Line from top to circle center.
    canvas.drawRect(
      Rect.fromLTWH(cx - 1, 0, 2, size.height / 2),
      paint,
    );

    // Circle at bottom.
    canvas.drawCircle(
      Offset(cx, size.height / 2 + ReaderSelectionHandle.handleRadius),
      ReaderSelectionHandle.handleRadius,
      paint,
    );
  }

  @override
  bool shouldRepaint(_HandlePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isStart != isStart;
}
