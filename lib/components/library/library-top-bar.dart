import 'package:flutter/material.dart';

import '../common/ui/top-icon-button.dart';
import '../../shared/constants/library-design-tokens.dart';

class LibraryTopBar extends StatelessWidget {
  const LibraryTopBar({
    required this.onSearchTap,
    required this.onMenuTap,
    required this.onImportTap,
    required this.isImporting,
    super.key,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;
  final VoidCallback onImportTap;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LibraryDesignTokens.topBarHeight,
      child: Row(
        children: <Widget>[
          const Text(
            'A2A',
            style: TextStyle(
              fontSize: LibraryDesignTokens.headerBrandSize,
              fontWeight: FontWeight.w900,
              color: LibraryDesignTokens.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          TopIconButton(icon: Icons.search, onTap: onSearchTap),
          TopIconButton(icon: Icons.menu, onTap: onMenuTap),
          TopIconButton(
            icon: isImporting ? Icons.hourglass_top : Icons.file_upload_outlined,
            onTap: isImporting ? null : onImportTap,
          ),
        ],
      ),
    );
  }
}
