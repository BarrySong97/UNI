import 'package:flutter/material.dart';

import '../../../entities/annotation-entity.dart';
import '../../../services/reader/annotation/annotation_text_utils.dart';
import '../../../shared/constants/reader-constants.dart';

class ReaderMarkStyleEditor extends StatelessWidget {
  const ReaderMarkStyleEditor({
    super.key,
    required this.selectedColor,
    required this.selectedStyle,
    required this.onColorChanged,
    required this.onStyleChanged,
    this.palette = ReaderConstants.markPalette,
  });

  static const double compactHeight = 56;
  static const double compactWidth = 280;

  final String selectedColor;
  final AnnotationStyle selectedStyle;
  final ValueChanged<String> onColorChanged;
  final ValueChanged<AnnotationStyle> onStyleChanged;
  final List<String> palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compactHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StyleButton(
            key: const ValueKey('mark-style-highlight'),
            icon: Icons.format_color_fill_rounded,
            isSelected: selectedStyle == AnnotationStyle.highlight,
            onTap: () => onStyleChanged(AnnotationStyle.highlight),
          ),
          const SizedBox(width: 8),
          _StyleButton(
            key: const ValueKey('mark-style-underline'),
            icon: Icons.format_underline_rounded,
            isSelected: selectedStyle == AnnotationStyle.underline,
            onTap: () => onStyleChanged(AnnotationStyle.underline),
          ),
          const SizedBox(width: 10),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in palette) ...[
                  _ColorSwatch(
                    key: ValueKey('mark-color-$color'),
                    color: annotationColorFromHex(color, alpha: 1),
                    isSelected: color == selectedColor,
                    onTap: () => onColorChanged(color),
                  ),
                  if (color != palette.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleButton extends StatelessWidget {
  const _StyleButton({
    super.key,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFCC80) : Colors.black87,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 24,
          color: isSelected ? Colors.black87 : Colors.white,
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: isSelected ? 2.2 : 1,
          ),
        ),
      ),
    );
  }
}
