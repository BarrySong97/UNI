import 'package:flutter/material.dart';

import '../../shared/constants/library-design-tokens.dart';

class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    required this.onImportTap,
    required this.isImporting,
    super.key,
  });

  final VoidCallback onImportTap;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: LibraryDesignTokens.avatarSize,
          height: LibraryDesignTokens.avatarSize,
          decoration: BoxDecoration(
            color: LibraryDesignTokens.avatarBg,
            borderRadius: BorderRadius.circular(LibraryDesignTokens.avatarRadius),
          ),
          alignment: Alignment.center,
          child: const Text(
            'U',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: LibraryDesignTokens.avatarTextColor,
            ),
          ),
        ),
        const Spacer(),
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
