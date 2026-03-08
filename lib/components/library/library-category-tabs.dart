import 'package:flutter/material.dart';

import '../common/ui/pill-tab.dart';
import '../../shared/constants/common-design-tokens.dart';

class LibraryCategoryTabs extends StatelessWidget {
  const LibraryCategoryTabs({
    required this.items,
    required this.active,
    required this.onChange,
    super.key,
  });

  final List<String> items;
  final String active;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CommonDesignTokens.tabHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final label = items[index];
          return PillTab(
            label: label,
            isActive: label == active,
            onTap: () => onChange(label),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: CommonDesignTokens.tabGap),
        itemCount: items.length,
      ),
    );
  }
}
