import 'package:flutter/material.dart';

import '../../shared/constants/library-design-tokens.dart';

class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    this.headerTitle = 'Shelf',
    this.onImportTap,
    this.isImporting = false,
    this.showImportButton = true,
    super.key,
  });

  final String headerTitle;
  final VoidCallback? onImportTap;
  final bool isImporting;
  final bool showImportButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'IMMERSED',
              style: TextStyle(
                fontSize: LibraryDesignTokens.headerLabelSize,
                fontWeight: FontWeight.w600,
                color: LibraryDesignTokens.headerLabelColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              headerTitle,
              style: const TextStyle(
                fontSize: LibraryDesignTokens.headerTitleSize,
                fontWeight: FontWeight.w700,
                color: LibraryDesignTokens.textPrimary,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (showImportButton)
          IconButton(
            icon: Icon(
              isImporting ? Icons.hourglass_top : Icons.add,
              color: LibraryDesignTokens.textPrimary,
              size: 22,
            ),
            onPressed: isImporting ? null : onImportTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
      ],
    );
  }
}
