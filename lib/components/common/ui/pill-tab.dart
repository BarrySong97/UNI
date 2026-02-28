import 'package:flutter/material.dart';

import '../../../shared/constants/library-design-tokens.dart';

class PillTab extends StatelessWidget {
  const PillTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: LibraryDesignTokens.tabHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: LibraryDesignTokens.tabHorizontalPadding,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? LibraryDesignTokens.tabActiveBg
              : LibraryDesignTokens.tabInactiveBg,
          border: Border.all(color: LibraryDesignTokens.borderColor),
          borderRadius: BorderRadius.circular(LibraryDesignTokens.tabBorderRadius),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: isActive
                ? LibraryDesignTokens.tabActiveText
                : LibraryDesignTokens.tabInactiveText,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
