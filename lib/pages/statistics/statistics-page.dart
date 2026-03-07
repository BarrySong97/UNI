import 'package:flutter/material.dart';

import '../../shared/constants/library-design-tokens.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LibraryDesignTokens.pageBackground,
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: LibraryDesignTokens.pageBackground,
        elevation: 0,
      ),
      body: const SizedBox.shrink(),
    );
  }
}
