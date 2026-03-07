import 'dart:ui';

import 'package:flutter/material.dart';

class FloatingTabBarItem {
  const FloatingTabBarItem({required this.icon, required this.activeIcon});

  final IconData icon;
  final IconData activeIcon;
}

class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final List<FloatingTabBarItem> items;
  final ValueChanged<int> onTap;

  static const _activeIconColor = Colors.white;
  static const _inactiveIconColor = Color(0xFF6B6B6B);
  static const _activePillColor = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 60, right: 60, bottom: 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / items.length;
                return Stack(
                  children: <Widget>[
                    // Animated background pill
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      left: currentIndex * itemWidth,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _activePillColor,
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                    // Icons row
                    Row(
                      children: List<Widget>.generate(items.length, (index) {
                        final item = items[index];
                        final isActive = currentIndex == index;
                        final targetColor = isActive
                            ? _activeIconColor
                            : _inactiveIconColor;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onTap(index),
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              height: 44,
                              child: Center(
                                child: TweenAnimationBuilder<Color?>(
                                  tween: ColorTween(end: targetColor),
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, color, _) {
                                    return Icon(
                                      isActive ? item.activeIcon : item.icon,
                                      size: 24,
                                      color: color,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
