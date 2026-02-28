import 'package:flutter/material.dart';

import '../../shared/constants/library-design-tokens.dart';

class LibraryHeroHeading extends StatelessWidget {
  const LibraryHeroHeading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Library',
      style: TextStyle(
        fontSize: LibraryDesignTokens.libraryTitleSize,
        fontWeight: FontWeight.w400,
        color: LibraryDesignTokens.textPrimary,
        height: 0.96,
        letterSpacing: -0.8,
      ),
    );
  }
}
