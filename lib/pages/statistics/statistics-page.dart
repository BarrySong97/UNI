import 'package:flutter/material.dart';

import '../../shared/constants/common-design-tokens.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommonDesignTokens.pageBackground,
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: CommonDesignTokens.pageBackground,
        elevation: 0,
      ),
      body: const SizedBox.shrink(),
    );
  }
}
