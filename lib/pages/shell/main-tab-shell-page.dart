import 'package:flutter/material.dart';

import '../../components/common/ui/floating-tab-bar.dart';
import '../../shared/constants/library-design-tokens.dart';
import '../library/library-page.dart';
import '../settings/settings-page.dart';
import '../shelf/shelf-page.dart';

class MainTabShellPage extends StatefulWidget {
  const MainTabShellPage({
    this.initialIndex = 0,
    this.pages,
    super.key,
  });

  final int initialIndex;
  final List<Widget>? pages;

  @override
  State<MainTabShellPage> createState() => _MainTabShellPageState();
}

class _MainTabShellPageState extends State<MainTabShellPage> {
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages ??
        const <Widget>[ShelfPage(), LibraryPage(), SettingsPage()];

    return Scaffold(
      backgroundColor: LibraryDesignTokens.pageBackground,
      body: Stack(
        children: <Widget>[
          IndexedStack(
            index: currentIndex,
            children: pages,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(
              currentIndex: currentIndex,
              onTap: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              items: const <FloatingTabBarItem>[
                FloatingTabBarItem(
                  icon: Icons.library_books_outlined,
                  activeIcon: Icons.library_books,
                ),
                FloatingTabBarItem(
                  icon: Icons.auto_stories_outlined,
                  activeIcon: Icons.auto_stories,
                ),
                FloatingTabBarItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
