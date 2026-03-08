import 'package:flutter/material.dart';

import '../../shared/constants/common-design-tokens.dart';

class WordOfDayPage extends StatelessWidget {
  const WordOfDayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommonDesignTokens.pageBackground,
      appBar: AppBar(
        title: const Text('Word of the Day'),
        backgroundColor: CommonDesignTokens.pageBackground,
        elevation: 0,
      ),
      body: const SizedBox.shrink(),
    );
  }
}
