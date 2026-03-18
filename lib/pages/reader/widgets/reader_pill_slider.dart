import 'package:flutter/material.dart';

/// Pill-shaped slider with a large white circular thumb and chevron arrows.
class ReaderPillSlider extends StatelessWidget {
  const ReaderPillSlider({
    super.key,
    required this.value,
    required this.textColor,
    required this.onChanged,
    this.onChangeEnd,
    this.onDecrement,
    this.onIncrement,
  });

  /// Normalized value in [0.0, 1.0].
  final double value;

  /// Text color from current reader theme (used to derive track/chevron colors).
  final Color textColor;

  /// Called continuously during drag with normalized value.
  final ValueChanged<double> onChanged;

  /// Called when drag ends.
  final VoidCallback? onChangeEnd;

  /// Called when left chevron is tapped.
  final VoidCallback? onDecrement;

  /// Called when right chevron is tapped.
  final VoidCallback? onIncrement;

  static const _trackHeight = 32.0;
  static const _thumbDiameter = 36.0;
  static const _thumbRadius = _thumbDiameter / 2;
  static const _chevronArea = 34.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final slideStart = _chevronArea;
        final slideEnd = trackWidth - _chevronArea;
        final slideRange = (slideEnd - slideStart).clamp(1.0, double.infinity);
        final thumbCenterX = slideStart + value.clamp(0.0, 1.0) * slideRange;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            final norm =
                ((d.localPosition.dx - slideStart) / slideRange).clamp(0.0, 1.0);
            onChanged(norm);
          },
          onHorizontalDragUpdate: (d) {
            final norm =
                ((d.localPosition.dx - slideStart) / slideRange).clamp(0.0, 1.0);
            onChanged(norm);
          },
          onHorizontalDragEnd: (_) => onChangeEnd?.call(),
          child: SizedBox(
            height: _thumbDiameter + 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Track background.
                Container(
                  height: _trackHeight,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(_trackHeight / 2),
                  ),
                ),
                // Left chevron.
                Positioned(
                  left: 8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDecrement,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: Icon(
                          Icons.chevron_left,
                          color: textColor.withValues(alpha: 0.35),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                // Right chevron.
                Positioned(
                  right: 8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onIncrement,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: Icon(
                          Icons.chevron_right,
                          color: textColor.withValues(alpha: 0.35),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                // Thumb.
                Positioned(
                  left: thumbCenterX - _thumbRadius,
                  child: IgnorePointer(
                    child: Container(
                      width: _thumbDiameter,
                      height: _thumbDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
