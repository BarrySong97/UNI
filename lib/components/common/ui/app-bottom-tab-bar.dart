import 'package:flutter/material.dart';

import '../../../shared/constants/library-design-tokens.dart';

class AppBottomTabItem {
  const AppBottomTabItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class AppBottomTabBar extends StatelessWidget {
  const AppBottomTabBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final List<AppBottomTabItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LibraryDesignTokens.bottomBarHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F0F0),
        border: Border(top: BorderSide(color: LibraryDesignTokens.borderColor)),
      ),
      child: Row(
        children: List<Widget>.generate(items.length, (index) {
          final item = items[index];
          final isActive = currentIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    item.icon,
                    size: LibraryDesignTokens.bottomIconSize,
                    color: isActive ? LibraryDesignTokens.textPrimary : LibraryDesignTokens.tabInactiveText,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: LibraryDesignTokens.bottomLabelSize,
                      fontWeight: FontWeight.w700,
                      color: isActive ? LibraryDesignTokens.textPrimary : LibraryDesignTokens.tabInactiveText,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
