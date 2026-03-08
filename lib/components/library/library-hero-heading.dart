import 'package:flutter/material.dart';

import '../../shared/constants/common-design-tokens.dart';

class LibraryHeroHeading extends StatelessWidget {
  const LibraryHeroHeading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Library',
      style: TextStyle(
        fontSize: CommonDesignTokens.libraryTitleSize,
        fontWeight: FontWeight.w400,
        color: CommonDesignTokens.textPrimary,
        height: 0.96,
        letterSpacing: -0.8,
      ),
    );
  }
}
