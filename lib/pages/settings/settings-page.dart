import 'package:flutter/material.dart';

import '../../shared/constants/library-design-tokens.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LibraryDesignTokens.pageBackground,
      alignment: Alignment.center,
      child: const Text(
        'Settings',
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w700,
          color: LibraryDesignTokens.textPrimary,
        ),
      ),
    );
  }
}
