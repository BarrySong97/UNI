import 'package:flutter/material.dart';

import '../common/ui/top-icon-button.dart';
import '../../shared/constants/common-design-tokens.dart';

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
      height: CommonDesignTokens.topBarHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TopIconButton(icon: Icons.search, onTap: onSearchTap),
          TopIconButton(icon: Icons.menu, onTap: onMenuTap),
          TopIconButton(
            icon: isImporting
                ? Icons.hourglass_top
                : Icons.file_upload_outlined,
            onTap: isImporting ? null : onImportTap,
          ),
        ],
      ),
    );
  }
}
