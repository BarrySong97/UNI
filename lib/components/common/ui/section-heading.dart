import 'package:flutter/material.dart';

import '../../../shared/constants/library-design-tokens.dart';

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    this.actionLabel,
    this.onActionTap,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: LibraryDesignTokens.recentTitleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: LibraryDesignTokens.textPrimary,
            height: 0.95,
          ),
        ),
        if (hasAction) ...<Widget>[
          const SizedBox(width: 8),
          InkWell(
            onTap: onActionTap,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: LibraryDesignTokens.textPrimary,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
