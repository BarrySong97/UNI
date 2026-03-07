import 'package:flutter/material.dart';

import '../../shared/constants/library-design-tokens.dart';

class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    required this.onImportTap,
    required this.isImporting,
    this.showImportButton = true,
    super.key,
  });

  final VoidCallback onImportTap;
  final bool isImporting;
  final bool showImportButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const Text(
          'Immersed',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: LibraryDesignTokens.textPrimary,
          ),
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
