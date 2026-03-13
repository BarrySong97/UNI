import 'package:flutter/material.dart';

import '../../../shared/constants/common-design-tokens.dart';

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
        height: CommonDesignTokens.tabHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: CommonDesignTokens.tabHorizontalPadding,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? CommonDesignTokens.tabActiveBg
              : CommonDesignTokens.tabInactiveBg,
          border: Border.all(color: CommonDesignTokens.borderColor),
          borderRadius: BorderRadius.circular(
            CommonDesignTokens.tabBorderRadius,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: isActive
                ? CommonDesignTokens.tabActiveText
                : CommonDesignTokens.tabInactiveText,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
