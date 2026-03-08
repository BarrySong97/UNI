import 'package:flutter/material.dart';

import '../../shared/constants/common-design-tokens.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CommonDesignTokens.pageBackground,
      alignment: Alignment.center,
      child: const Text(
        'Discover',
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w700,
          color: CommonDesignTokens.textPrimary,
        ),
      ),
    );
  }
}
